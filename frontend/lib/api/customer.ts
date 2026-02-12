import { api } from "./axios";
import {
  CustomerAllResponse,
  CustomerResponse,
  CustomerCreateRequest,
  CustomerUpdateRequest,
} from "@/types/customer";

export const customerApi = {
  async getAll(): Promise<CustomerAllResponse> {
    const res = await api.get<CustomerAllResponse>("/api/customers/");
    return res.data;
  },

  async getOne(id: string): Promise<CustomerResponse> {
    const res = await api.get<CustomerResponse>(`/api/customers/${id}/`);
    return res.data;
  },

  async create(data: CustomerCreateRequest): Promise<CustomerResponse> {
    const res = await api.post<CustomerResponse>("/api/customers/", data);
    return res.data;
  },

  async update(
    id: string,
    data: CustomerUpdateRequest,
  ): Promise<CustomerResponse> {
    const res = await api.put<CustomerResponse>(`/api/customers/${id}/`, data);
    return res.data;
  },

  async delete(id: string): Promise<void> {
    await api.delete(`/api/customers/${id}/`);
  },
};
