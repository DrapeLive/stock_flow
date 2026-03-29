import type { Item } from "./item";

export type OrderStatus = "PENDING" | "PACKED" | "DISPATCHED";

export interface SimpleAgent {
  id: number;
  username: string;
  contact: string;
}

export interface SimpleCustomer {
  id: number;
  name: string;
  contact: string;
}

export interface OrderItem {
  id: number;
  item: Item;
  size_group?: string;
  quantity: number;
  packed_quantity?: number;
  order: number;
  variant: number | null;
}

export interface Order {
  id: number;
  items: OrderItem[];
  agent_details: SimpleAgent;
  customer_details: SimpleCustomer;
  total_quantity: string;
  status?: OrderStatus;
  created_at: string;
  agent: number;
}

export interface OrderRegisterRequest {
  customer: number;
  status?: OrderStatus;
  agent: number;
}

export interface OrderRegisterResponse extends Order {}

export interface AddOrderItemRequest {
  qr_code: string;
  quantity: number;
  size_group: string;
}

export interface UpdateOrderItemRequest {
  size_group?: string;
  quantity?: number;
  packed_quantity?: number;
  variant?: number | null;
}

export interface UpdateOrderRequest {
  customer?: number;
  status?: OrderStatus;
  agent?: number;
}

export type OrderAllResponse = Order[];
export type OrderResponse = Order;
export type OrderItems = Order["items"];

export interface InvoiceCustomer {
  id: number;
  name: string;
  contact: string;
}

export interface InvoiceAgent {
  id: number;
  username: string;
  contact: string;
}

export interface InvoiceResponse {
  id: number;
  customer: InvoiceCustomer;
  agent: InvoiceAgent;
  created_at: string;
  status: OrderStatus;
  items: OrderItem[];
  total_price: number;
}
