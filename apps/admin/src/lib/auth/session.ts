const SESSION_MARKER = 'fixhubAdminSession';
const SESSION_MAX_AGE_SECONDS = 7 * 24 * 60 * 60;

export function setAdminSessionMarker() {
  if (typeof document === 'undefined') return;

  const secure = window.location.protocol === 'https:' ? '; Secure' : '';
  document.cookie = `${SESSION_MARKER}=1; Path=/; Max-Age=${SESSION_MAX_AGE_SECONDS}; SameSite=Lax${secure}`;
}

export function clearAdminSessionMarker() {
  if (typeof document === 'undefined') return;

  document.cookie = `${SESSION_MARKER}=; Path=/; Max-Age=0; SameSite=Lax`;
  document.cookie = `${SESSION_MARKER}=; Path=/; Max-Age=0; SameSite=Lax; Secure`;
  document.cookie = `accessToken=; Path=/; Max-Age=0; SameSite=Lax`;
  document.cookie = `accessToken=; Path=/; Max-Age=0; SameSite=Lax; Secure`;
  document.cookie = `refreshToken=; Path=/; Max-Age=0; SameSite=Lax`;
  document.cookie = `refreshToken=; Path=/; Max-Age=0; SameSite=Lax; Secure`;
}

export { SESSION_MARKER };
