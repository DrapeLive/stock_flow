import type { operations } from "@/types/api";

export type OrderAllResponse =
  operations["orders_list"]["responses"][200]["content"]["application/json"];

export type OrderResponse =
  operations["orders_retrieve"]["responses"][200]["content"]["application/json"];

export type OrderItems =
  operations["orders_retrieve"]["responses"][200]["content"]["application/json"]["items"];
