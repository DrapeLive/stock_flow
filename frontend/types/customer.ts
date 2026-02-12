import type { operations } from "@/types/api";

export type CustomerAllResponse =
  operations["customers_list"]["responses"][200]["content"]["application/json"];

export type CustomerResponse =
  operations["customers_retrieve"]["responses"][200]["content"]["application/json"];

export type CustomerCreateRequest =
  operations["customers_create"]["requestBody"]["content"]["application/json"];

export type CustomerUpdateRequest =
  operations["customers_update"]["requestBody"]["content"]["application/json"];
