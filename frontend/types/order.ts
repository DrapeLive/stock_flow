import type { operations } from "@/types/api";

export type OrderAllResponse =
  operations["orders_list"]["responses"][200]["content"]["application/json"];

export type OrderResponse =
  operations["orders_retrieve"]["responses"][200]["content"]["application/json"];

export type OrderItems =
  operations["orders_retrieve"]["responses"][200]["content"]["application/json"]["items"];

export type OrderRequest =
  operations["orders_add_item_create"]["requestBody"]["content"]["application/json"];

export type OrderAddItemResponse =
  operations["orders_add_item_create"]["responses"]["201"]["content"]["application/json"];

export type OrderRegisterRequest =
  operations["orders_create"]["requestBody"]["content"]["application/json"];

export type OrderRegisterResponse =
  operations["orders_create"]["responses"]["201"]["content"]["application/json"];
