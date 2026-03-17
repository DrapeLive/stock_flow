import {
  AddOrderItemRequest,
  InvoiceResponse,
  OrderAddItemResponse,
  OrderAllResponse,
  OrderDeleteResponse,
  OrderItemDeleteResponse,
  OrderItems,
  OrderRegisterRequest,
  OrderRegisterResponse,
  OrderRequest,
  OrderResponse,
} from "@/types/order";
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

  async addItem(
    data: AddOrderItemRequest,
    id: string,
  ): Promise<OrderAddItemResponse> {
    const res = await api.post<OrderAddItemResponse>(
      `/api/orders/${id}/add-item/`,
      data,
    );
    return res.data;
  },

  async create(data: OrderRegisterRequest): Promise<OrderRegisterResponse> {
    const res = await api.post<OrderRegisterResponse>(`/api/orders/`, data);
    return res.data;
  },

  async delete(id: string): Promise<OrderDeleteResponse> {
    const res = await api.delete<OrderDeleteResponse>(`/api/orders/${id}/`);
    return res.data;
  },

  async deleteItem(
    orderId: string,
    itemId: string,
  ): Promise<OrderItemDeleteResponse> {
    const res = await api.delete<OrderItemDeleteResponse>(
      `/api/orders/${orderId}/delete-item/${itemId}/`,
    );
    return res.data;
  },

  async update(id: number, data: any): Promise<OrderResponse> {
    const res = await api.patch<OrderResponse>(`/api/orders/${id}/`, data);
    return res.data;
  },

  async updateItem(itemId: number, data: any): Promise<any> {
    const res = await api.patch<any>(
      `/api/orders/order-items/${itemId}/`,
      data,
    );
    return res.data;
  },

  async invoiceOrder(id: number): Promise<InvoiceResponse> {
    const res = await api.get<InvoiceResponse>(`/api/orders/${id}/invoice/`);
    return res.data;
  },
};
