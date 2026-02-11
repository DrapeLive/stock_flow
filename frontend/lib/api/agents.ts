import { AgentAllResponse, AgentResponse } from "@/types/agent";
import { api } from "./axios";

export const agentApi = {
  async getAll(): Promise<AgentAllResponse> {
    const res = await api.get<AgentAllResponse>("/api/agents/");
    return res.data;
  },

  async getOne(id: number | undefined): Promise<AgentResponse> {
    const res = await api.get<AgentResponse>(`/api/agents/profile/${id}`);
    return res.data;
  },
};
