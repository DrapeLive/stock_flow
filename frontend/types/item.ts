import type { operations } from "@/types/api";

export type ItemAllResponse =
  operations["items_list"]["responses"][200]["content"]["application/json"];
