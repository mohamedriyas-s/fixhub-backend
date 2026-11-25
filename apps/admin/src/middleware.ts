import type { NextRequest } from 'next/server';
import { NextResponse } from 'next/server';

const publicRoutes = ['/login', '/_next', '/favicon.ico', '/api'];
const sessionMarker = 'fixhubAdminSession';

export async function middleware(request: NextRequest) {
  const { pathname, searchParams } = request.nextUrl;

  // Skip Next.js internal paths and static assets
  if (publicRoutes.some((route) => pathname.startsWith(route)) && pathname !== '/login') {
    return NextResponse.next();
  }

  const isAuthRoute = pathname === '/login';

  // If visiting /login:
  // If explicitly requested with ?expired or ?logout, clear any lingering auth cookies
  if (isAuthRoute) {
    if (searchParams.has('expired') || searchParams.has('logout')) {
      const response = NextResponse.next();
      response.cookies.delete('accessToken');
      response.cookies.delete('refreshToken');
      response.cookies.delete(sessionMarker);
      return response;
    }
    // Never blindly redirect from /login to / to prevent infinite reload loops
    // when backend session is revoked or expired.
    return NextResponse.next();
  }

  const accessToken = request.cookies.get('accessToken')?.value;
  const refreshToken = request.cookies.get('refreshToken')?.value;
  const adminSession = request.cookies.get(sessionMarker)?.value;

  const hasToken = !!accessToken || !!refreshToken || adminSession === '1';

  if (!hasToken) {
    // Unauthenticated user trying to access protected route -> redirect to login
    const loginUrl = new URL('/login', request.url);
    const response = NextResponse.redirect(loginUrl);
    response.cookies.delete('accessToken');
    response.cookies.delete('refreshToken');
    response.cookies.delete(sessionMarker);
    return response;
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - api (API routes)
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     */
    '/((?!api|_next/static|_next/image|favicon.ico).*)',
  ],
};
