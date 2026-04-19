import type {
  OrderAllResponse,
  OrderResponse,
  OrderRegisterRequest,
  OrderRegisterResponse,
  AddOrderItemRequest,
  UpdateOrderRequest,
  UpdateOrderItemRequest,
  InvoiceResponse,
} from "@/types/order";
import { api } from "./axios";

export interface OrderLog {
  id: number;
  action: string;
  details: Record<string, unknown>;
  performed_by: string | null;
  created_at: string;
}

export const orderApi = {
  getAll(): Promise<OrderAllResponse> {
    return api.get<OrderAllResponse>("/api/orders/").then((r) => r.data);
  },

  getByCustomer(customerId: number): Promise<OrderAllResponse> {
    return api.get<OrderAllResponse>(`/api/orders/?customer=${customerId}`).then((r) => r.data);
  },

  getOne(id: number): Promise<OrderResponse> {
    return api.get<OrderResponse>(`/api/orders/${id}/`).then((r) => r.data);
  },

  create(data: OrderRegisterRequest): Promise<OrderRegisterResponse> {
    return api
      .post<OrderRegisterResponse>("/api/orders/", data)
      .then((r) => r.data);
  },

  addItem(orderId: number, itemData: AddOrderItemRequest): Promise<void> {
    return api
      .post(`/api/orders/${orderId}/add-item/`, itemData)
      .then((r) => r.data);
  },

  update(id: number, data: UpdateOrderRequest): Promise<OrderResponse> {
    return api
      .patch<OrderResponse>(`/api/orders/${id}/`, data)
      .then((r) => r.data);
  },

  updateItem(itemId: number, data: UpdateOrderItemRequest) {
    return api
      .patch(`/api/orders/order-items/${itemId}/`, data)
      .then((r) => r.data);
  },

  delete(id: number): Promise<void> {
    return api.delete(`/api/orders/${id}/`).then((r) => r.data);
  },

  deleteItem(orderId: number, itemId: number): Promise<void> {
    return api
      .delete(`/api/orders/${orderId}/delete-item/${itemId}/`)
      .then((r) => r.data);
  },

  invoiceOrder(id: number): Promise<InvoiceResponse> {
    return api
      .get<InvoiceResponse>(`/api/orders/${id}/invoice/`)
      .then((r) => r.data);
  },

  placeOrder(id: number): Promise<{ message: string; order_id: number }> {
    return api
      .post<{ message: string; order_id: number }>(`/api/orders/${id}/place-order/`)
      .then((r) => r.data);
  },

  dispatchOrder(id: number): Promise<{ message: string }> {
    return api
      .post<{ message: string }>(`/api/orders/${id}/dispatch/`)
      .then((r) => r.data);
  },

  getOrderLogs(orderId: number): Promise<OrderLog[]> {
    return api
      .get<OrderLog[]>(`/api/orders/${orderId}/logs/`)
      .then((r) => r.data);
  },
};
