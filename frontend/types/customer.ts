import type { operations } from "@/types/api";

export type CustomerAllResponse =
  operations["customers_list"]["responses"][200]["content"]["application/json"];
