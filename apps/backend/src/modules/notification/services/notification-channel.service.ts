import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createSign } from 'crypto';

import { PrismaService } from '../../../common/database/prisma.service';

export interface DeliveryResult {
  status: 'SENT' | 'SKIPPED';
  providerMessageId?: string;
  reason?: string;
}

@Injectable()
export class PushNotificationChannel {
  private readonly logger = new Logger(PushNotificationChannel.name);
  private cachedAccessToken: string | null = null;
  private tokenExpiresAt: number = 0;

  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  async send(params: {
    tokens: string[];
    title: string;
    body: string;
    data?: Record<string, unknown>;
  }): Promise<DeliveryResult> {
    if (params.tokens.length === 0) {
      return { status: 'SKIPPED', reason: 'NO_ACTIVE_DEVICE_TOKENS' };
    }

    const projectId = this.configService.get<string>('firebase.projectId');
    const accessToken = await this.getAccessToken();

    if (!projectId || !accessToken) {
      this.logger.warn('Firebase credentials missing; push delivery skipped');
      return { status: 'SKIPPED', reason: 'FIREBASE_NOT_CONFIGURED' };
    }

    let successCount = 0;
    const errors: string[] = [];

    await Promise.all(
      params.tokens.map(async (token) => {
        try {
          const response = await fetch(
            `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
            {
              method: 'POST',
              headers: {
                Authorization: `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                message: {
                  token,
                  notification: { title: params.title, body: params.body },
                  data: {
                    ...this.stringifyData(params.data),
                    title: params.title,
                    body: params.body,
                  },
                  android: {
                    priority: 'high',
                    notification: {
                      channelId: 'fixhub_booking_alerts',
                      sound: 'default',
                      defaultSound: true,
                      notificationPriority: 'PRIORITY_MAX',
                    },
                  },
                },
              }),
            },
          );

          if (response.ok) {
            successCount++;
          } else {
            const errorBody = await response.text();
            this.logger.warn(
              `FCM delivery failed for token ${token.slice(0, 10)}...: ${response.status} ${errorBody}`,
            );

            // Auto-prune dead/unregistered tokens (HTTP 404 or UNREGISTERED)
            if (
              response.status === 404 ||
              errorBody.includes('UNREGISTERED') ||
              response.status === 400
            ) {
              await this.deactivateToken(token);
            }
            errors.push(`Status ${response.status}`);
          }
        } catch (err) {
          this.logger.error(`Error sending push to token: ${token.slice(0, 10)}...`, err);
          errors.push((err as Error).message);
        }
      }),
    );

    if (successCount === 0 && errors.length > 0) {
      throw new Error(`All FCM deliveries failed: ${errors.join(', ')}`);
    }

    return {
      status: successCount > 0 ? 'SENT' : 'SKIPPED',
      providerMessageId: `fcm:${Date.now()}:success=${successCount}`,
    };
  }

  private async deactivateToken(token: string) {
    try {
      await this.prisma.deviceToken.updateMany({
        where: { token },
        data: { isActive: false },
      });
      this.logger.log(`Deactivated invalid/unregistered FCM token: ${token.slice(0, 10)}...`);
    } catch (e) {
      this.logger.error(`Failed to deactivate token in DB: ${e}`);
    }
  }

  private stringifyData(data?: Record<string, unknown>) {
    return Object.fromEntries(
      Object.entries(data ?? {}).map(([key, value]) => [key, String(value)]),
    );
  }

  private async getAccessToken(): Promise<string | null> {
    const now = Math.floor(Date.now() / 1000);
    // Reuse cached OAuth2 token if valid for at least 5 more minutes
    if (this.cachedAccessToken && this.tokenExpiresAt > now + 300) {
      return this.cachedAccessToken;
    }

    const clientEmail = this.configService.get<string>('firebase.clientEmail');
    let privateKey = this.configService.get<string>('firebase.privateKey');

    if (!clientEmail || !privateKey) {
      return null;
    }

    privateKey = privateKey.replace(/\\n/g, '\n');

    try {
      const header = this.base64Url({ alg: 'RS256', typ: 'JWT' });
      const claim = this.base64Url({
        iss: clientEmail,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: 'https://oauth2.googleapis.com/token',
        iat: now,
        exp: now + 3600,
      });
      const unsigned = `${header}.${claim}`;
      const signature = createSign('RSA-SHA256').update(unsigned).sign(privateKey, 'base64url');
      const jwt = `${unsigned}.${signature}`;

      const response = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          assertion: jwt,
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        this.logger.error(
          `Firebase token request failed with status ${response.status}: ${errorText}`,
        );
        return null;
      }

      const payload = (await response.json()) as { access_token?: string; expires_in?: number };
      if (payload.access_token) {
        this.cachedAccessToken = payload.access_token;
        this.tokenExpiresAt = now + (payload.expires_in ?? 3600);
        return this.cachedAccessToken;
      }
      return null;
    } catch (err) {
      this.logger.error('Failed to generate Google OAuth2 token for Firebase', err);
      return null;
    }
  }

  private base64Url(value: unknown) {
    return Buffer.from(JSON.stringify(value)).toString('base64url');
  }
}

@Injectable()
export class SmsNotificationChannel {
  private readonly logger = new Logger(SmsNotificationChannel.name);

  constructor(private readonly configService: ConfigService) {}

  async send(params: { phone?: string; body: string }): Promise<DeliveryResult> {
    if (!params.phone) {
      return { status: 'SKIPPED', reason: 'NO_PHONE' };
    }

    const apiKey = this.configService.get<string>('sms.apiKey');
    const provider = this.configService.get<string>('sms.provider') || 'DEV';

    // If an API key is provided, dispatch real SMS via selected gateway
    if (apiKey) {
      try {
        if (provider === 'FAST2SMS') {
          const number = params.phone.trim().replace(/^\+91/, '');
          if (!/^[6-9]\d{9}$/.test(number)) {
            throw new Error('Fast2SMS requires a valid Indian mobile number');
          }

          const response = await fetch('https://www.fast2sms.com/dev/bulkV2', {
            method: 'POST',
            headers: {
              authorization: apiKey,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              route: 'q',
              message: params.body,
              numbers: number,
            }),
          });
          const result: { return?: boolean; request_id?: string; status_code?: number } | null =
            await response.json();
          if (!response.ok || result?.return !== true || !result.request_id) {
            const code = Number.isInteger(result?.status_code)
              ? result?.status_code
              : response.status;
            throw new Error(`Fast2SMS rejected the SMS request (code ${code})`);
          }

          return { status: 'SENT', providerMessageId: result.request_id };
        } else if (provider === 'MSG91') {
          // MSG91 API
          await fetch('https://control.msg91.com/api/v5/flow/', {
            method: 'POST',
            headers: {
              authkey: apiKey,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              recipients: [{ mobiles: params.phone.replace('+', '') }],
            }),
          });
          return { status: 'SENT', providerMessageId: `msg91:${Date.now()}` };
        }
      } catch (err) {
        this.logger.error(`SMS dispatch via ${provider} failed:`, err);
        throw err;
      }
    }

    const environment = this.configService.get<string>('nodeEnv');
    if ((environment === 'development' || environment === 'test') && provider === 'DEV') {
      return { status: 'SENT', providerMessageId: `simulated:${Date.now()}` };
    }
    throw new Error('SMS delivery requires a configured provider and API key');
  }
}

@Injectable()
export class EmailNotificationChannel {
  async send(params: {
    email?: string | null;
    subject: string;
    body: string;
  }): Promise<DeliveryResult> {
    if (!params.email) {
      return { status: 'SKIPPED', reason: 'NO_EMAIL' };
    }

    return { status: 'SENT', providerMessageId: `email:${Date.now()}` };
  }
}
