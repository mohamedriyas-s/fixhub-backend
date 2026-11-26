export interface JwtPayload {
  sub: string; // userId
  phone: string | null;
  role: string;
}

export interface AuthenticatedUser {
  userId: string;
  phone: string | null;
  role: string;
}
