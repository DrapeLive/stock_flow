import type {
  AgentAllResponse,
  AgentResponse,
  AgentRequest,
  AgentUpdateRequest,
} from "@/types/agent";
import { api } from "./axios";

export const agentApi = {
  getAll(): Promise<AgentAllResponse> {
    return api.get<AgentAllResponse>("/api/agents/").then((r) => r.data);
  },

  getProfile(userId: number): Promise<AgentResponse> {
    return api
      .get<AgentResponse>(`/api/agents/profile/${userId}/`)
      .then((r) => r.data);
  },

  getOne(id: number): Promise<AgentResponse> {
    return api.get<AgentResponse>(`/api/agents/${id}/`).then((r) => r.data);
  },

  create(data: AgentRequest): Promise<AgentResponse> {
    return api.post<AgentResponse>("/api/agents/", data).then((r) => r.data);
  },

  update(id: number, data: AgentUpdateRequest): Promise<AgentResponse> {
    return api
      .patch<AgentResponse>(`/api/agents/${id}/`, data)
      .then((r) => r.data);
  },

  delete(id: number): Promise<void> {
    return api.delete(`/api/agents/${id}/`).then((r) => r.data);
  },
};
