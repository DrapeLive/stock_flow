import type { Business } from "@/types/auth";

export interface Admin {
  id: number;
  username: string;
  email: string;
  business?: Business | null;
}

export interface AdminRequest {
  username: string;
  email: string;
  password: string;
  business?: Business | null;
}

export interface AdminUpdateRequest {
  username?: string;
  email?: string;
  password?: string;
}

export type AdminAllResponse = Admin[];
export type AdminResponse = Admin;
