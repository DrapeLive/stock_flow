import type { components, operations } from "@/types/api";

export type LoginRequest =
  operations["auth_login_create"]["requestBody"]["content"]["application/json"];

export type LoginResponse =
  operations["auth_login_create"]["responses"][200]["content"]["application/json"];

export type Role = components["schemas"]["RoleEnum"];

export interface AuthUser {
  id: number;
  role: Role;
}
