import { AdminAllResponse, AdminRequest, AdminResponse } from "@/types/admin";
import { api } from "./axios";

export const adminApi = {
  async getAll(): Promise<AdminAllResponse> {
    const res = await api.get<AdminAllResponse>("/api/admins/");
    return res.data;
  },

  async getOne(id: number | string): Promise<AdminResponse> {
    const res = await api.get<AdminResponse>(`/api/admins/${id}/`);
    return res.data;
  },

  async create(data: AdminRequest): Promise<AdminResponse> {
    const res = await api.post<AdminResponse>("/api/admins/", data);
    return res.data;
  },

  async update(id: number | string, data: Partial<AdminRequest>): Promise<AdminResponse> {
    const res = await api.put<AdminResponse>(`/api/admins/${id}/`, data);
    return res.data;
  },

  async delete(id: number | string): Promise<void> {
    await api.delete(`/api/admins/${id}/`);
  },
};
