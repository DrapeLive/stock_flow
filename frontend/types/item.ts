import type { operations } from "@/types/api";

export type ItemAllResponse =
  operations["items_list"]["responses"][200]["content"]["application/json"];

export type ItemResponse =
  operations["items_retrieve"]["responses"][200]["content"]["application/json"];

export type ItemRequest =
  operations["items_create"]["requestBody"]["content"]["application/json"];
