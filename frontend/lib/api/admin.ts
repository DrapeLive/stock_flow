import { AdminAllResponse, AdminRequest, AdminResponse } from "@/types/admin";
import { api } from "./axios";

export const adminApi = {
  async getAll(): Promise<AdminAllResponse> {
    const res = await api.get<AdminAllResponse>("/api/admins/");
    return res.data;
  },

  async getOne(id: number | undefined): Promise<AdminResponse> {
    const res = await api.get<AdminResponse>(`/api/admins/profile/${id}`);
    return res.data;
  },

  async create(data: AdminRequest): Promise<AdminResponse> {
    const res = await api.post<AdminResponse>("/api/admins/", data);
    return res.data;
  },
};
