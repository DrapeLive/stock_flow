import type { operations } from "@/types/api";

export type AdminAllResponse =
  operations["admins_list"]["responses"][200]["content"]["application/json"];

export type AdminResponse =
  operations["admins_retrieve"]["responses"][200]["content"]["application/json"];

export type AdminRequest =
  operations["admins_create"]["requestBody"]["content"]["application/json"];
