import type { operations } from "@/types/api";

export type AgentAllResponse =
  operations["agents_list"]["responses"][200]["content"]["application/json"];
