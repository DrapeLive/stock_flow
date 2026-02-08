import type { operations } from "@/types/api";

export type OrderAllResponse =
  operations["orders_list"]["responses"][200]["content"]["application/json"];
