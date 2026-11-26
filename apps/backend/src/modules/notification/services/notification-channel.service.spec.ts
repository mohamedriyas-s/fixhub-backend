import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { SmsNotificationChannel } from './notification-channel.service';

describe('Fast2SMS delivery', () => {
  const phone = '8190899870';
  const body = 'Your HelpTab verification code is: 123456.';
  const channel = new SmsNotificationChannel(
    new ConfigService({ nodeEnv: 'production', sms: { provider: 'FAST2SMS', apiKey: 'mock-key' } }),
  );

  afterEach(() => jest.restoreAllMocks());

  it.each([phone, `+91${phone}`])('submits the OTP for %s', async (recipient) => {
    const fetchMock = jest
      .spyOn(global, 'fetch')
      .mockResolvedValue(Response.json({ return: true, request_id: 'test-request' }));

    await expect(channel.send({ phone: recipient, body })).resolves.toEqual({
      status: 'SENT',
      providerMessageId: 'test-request',
    });

    expect(fetchMock).toHaveBeenCalledWith('https://www.fast2sms.com/dev/bulkV2', {
      method: 'POST',
      headers: { authorization: 'mock-key', 'Content-Type': 'application/json' },
      body: JSON.stringify({ route: 'q', message: body, numbers: phone }),
    });
  });

  it('rejects a provider error even when the HTTP request succeeds', async () => {
    jest.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);
    jest
      .spyOn(global, 'fetch')
      .mockResolvedValue(Response.json({ return: false, status_code: 999 }));

    await expect(channel.send({ phone, body })).rejects.toThrow('code 999');
  });
});
