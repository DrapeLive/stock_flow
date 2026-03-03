import { AgentAllResponse, AgentRequest, AgentResponse } from "@/types/agent";
import { api } from "./axios";

export const agentApi = {
  async getAll(): Promise<AgentAllResponse> {
    const res = await api.get<AgentAllResponse>("/api/agents/");
    return res.data;
  },

  async getOne(id: number | string): Promise<AgentResponse> {
    const res = await api.get<AgentResponse>(`/api/agents/${id}/`);
    return res.data;
  },

  async create(data: AgentRequest): Promise<AgentResponse> {
    const res = await api.post<AgentResponse>("/api/agents/", data);
    return res.data;
  },

  async update(id: number | string, data: Partial<AgentRequest>): Promise<AgentResponse> {
    const res = await api.put<AgentResponse>(`/api/agents/${id}/`, data);
    return res.data;
  },

  async delete(id: number | string): Promise<void> {
    await api.delete(`/api/agents/${id}/`);
  },
};
