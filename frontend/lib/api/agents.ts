import { AgentAllResponse } from "@/types/agent";
import { api } from "./axios";

export const agentApi = {
  async getAll(): Promise<AgentAllResponse> {
    const res = await api.get<AgentAllResponse>("/api/agents/");
    return res.data;
  },
};
