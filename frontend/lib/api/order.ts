import { OrderAllResponse } from "@/types/order";
import { api } from "./axios";

export const orderApi = {
  async getAll(): Promise<OrderAllResponse> {
    const res = await api.get<OrderAllResponse>("/api/orders/");
    return res.data;
  },
};
