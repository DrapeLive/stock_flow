import { OrderAllResponse, OrderResponse } from "@/types/order";
import { api } from "./axios";

export const orderApi = {
  async getAll(): Promise<OrderAllResponse> {
    const res = await api.get<OrderAllResponse>("/api/orders/");
    return res.data;
  },

  async getOne(id: number): Promise<OrderResponse> {
    const res = await api.get<OrderResponse>(`/api/orders/${id}`);
    return res.data;
  },
};
