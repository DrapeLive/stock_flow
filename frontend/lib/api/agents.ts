import type {
  AgentAllResponse,
  AgentResponse,
  AgentRequest,
  AgentUpdateRequest,
  AssignedItem,
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

  getItems(agentId: number): Promise<AssignedItem[]> {
    return api
      .get<AssignedItem[]>(`/api/agents/${agentId}/items/`)
      .then((r) => r.data);
  },

  updateItems(agentId: number, itemIds: number[]): Promise<AssignedItem[]> {
    return api
      .post<AssignedItem[]>(`/api/agents/${agentId}/items/`, {
        item_ids: itemIds,
      })
      .then((r) => r.data);
  },

  removeItem(agentId: number, itemId: number): Promise<void> {
    return api
      .delete(`/api/agents/${agentId}/items/${itemId}/`)
      .then((r) => r.data);
  },
};
