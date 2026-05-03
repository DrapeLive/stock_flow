import type { Business } from "@/types/auth";

export interface Admin {
  id: number;
  username: string;
  email: string;
  display_name?: string;
  business?: Business | null;
  brand_id?: number | null;
}

export interface AdminRequest {
  username: string;
  email: string;
  password: string;
  display_name?: string;
  business?: Business | null;
  brand_id?: number | null;
}

export interface AdminUpdateRequest {
  username?: string;
  email?: string;
  password?: string;
  display_name?: string;
  business?: Business | null;
  brand_id?: number | null;
}

export type AdminAllResponse = Admin[];
export type AdminResponse = Admin;
