export type Role = "ADMIN" | "AGENT";

export interface LoginRequest {
  username?: string;
  email?: string;
  password: string;
}

export interface LoginResponse {
  access: string;
  refresh: string;
  role: Role;
  user_id: number;
}

export interface AuthUser {
  id: number;
  role: Role;
  username?: string;
  email?: string;
}

export interface UserProfile {
  id: number;
  username: string;
  email: string;
  role: Role;
}
