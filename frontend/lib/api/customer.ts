import type {
  CustomerAllResponse,
  CustomerResponse,
  CustomerCreateRequest,
  CustomerUpdateRequest,
} from "@/types/customer";
import { api } from "./axios";

export const customerApi = {
  getAll(): Promise<CustomerAllResponse> {
    return api.get<CustomerAllResponse>("/api/customers/").then((r) => r.data);
  },

  getOne(id: number): Promise<CustomerResponse> {
    return api.get<CustomerResponse>(`/api/customers/${id}/`).then((r) => r.data);
  },

  create(data: CustomerCreateRequest): Promise<CustomerResponse> {
    return api
      .post<CustomerResponse>("/api/customers/", data)
      .then((r) => r.data);
  },

  update(id: number, data: CustomerUpdateRequest): Promise<CustomerResponse> {
    return api
      .patch<CustomerResponse>(`/api/customers/${id}/`, data)
      .then((r) => r.data);
  },

  delete(id: number): Promise<void> {
    return api.delete(`/api/customers/${id}/`).then((r) => r.data);
  },
};
