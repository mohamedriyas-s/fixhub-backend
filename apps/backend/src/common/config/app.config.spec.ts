import 'reflect-metadata';

import { validateConfig } from './app.config';

describe('Production email OTP configuration', () => {
  const environment = {
    NODE_ENV: 'production',
    DATABASE_URL: 'postgresql://localhost/fixhub',
    JWT_ACCESS_SECRET: 'test-access-secret',
    JWT_REFRESH_SECRET: 'test-refresh-secret',
  };

  it.each([{ RESEND_API_KEY: 'test-key' }, { OTP_EMAIL_FROM: 'login@example.com' }])(
    'requires both Resend settings in production',
    (settings) => {
      expect(() => validateConfig({ ...environment, ...settings })).toThrow(
        'production requires RESEND_API_KEY and OTP_EMAIL_FROM',
      );
    },
  );

  it('accepts configured production email delivery', () => {
    expect(
      validateConfig({
        ...environment,
        RESEND_API_KEY: 'test-key',
        OTP_EMAIL_FROM: 'login@example.com',
      }).NODE_ENV,
    ).toBe('production');
  });
});
