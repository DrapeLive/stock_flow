import type { operations } from "@/types/api";

export type AgentAllResponse =
  operations["agents_list"]["responses"][200]["content"]["application/json"];

export type AgentResponse =
  operations["agents_retrieve"]["responses"][200]["content"]["application/json"];
