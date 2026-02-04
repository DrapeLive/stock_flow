import type { components } from "@/types/api";

export type LoginResponse = components["schemas"]["LoginResponse"];
export type Role = components["schemas"]["RoleEnum"];

export interface AuthUser {
  id: number;
  role: Role;
}
