import { api } from "./axios";
import { CustomerAllResponse } from "@/types/customer";

export const customerApi = {
  async getAll(): Promise<CustomerAllResponse> {
    const res = await api.get<CustomerAllResponse>("/api/customers/");
    return res.data;
  },
};
