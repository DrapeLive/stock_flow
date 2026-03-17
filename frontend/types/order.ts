import type { components, operations } from "@/types/api";

export type OrderStatus = components["schemas"]["StatusEnum"];

export type OrderAllResponse =
  operations["orders_list"]["responses"][200]["content"]["application/json"];

export type OrderResponse =
  operations["orders_retrieve"]["responses"][200]["content"]["application/json"];

export type OrderItems =
  operations["orders_retrieve"]["responses"][200]["content"]["application/json"]["items"];

export type OrderRequest = operations["orders_add_item_create"]["requestBody"];

export type OrderAddItemResponse =
  operations["orders_add_item_create"]["responses"]["200"]["content"];

export type OrderRegisterRequest =
  operations["orders_create"]["requestBody"]["content"]["application/json"];

export type OrderRegisterResponse =
  operations["orders_create"]["responses"]["201"]["content"]["application/json"];

export type OrderDeleteResponse =
  operations["orders_destroy"]["responses"]["204"]["content"];

export type OrderItemDeleteResponse =
  operations["orders_delete_item_destroy"]["responses"]["204"]["content"];

export type AddOrderItemRequest = {
  qr_code: string;
  quantity: number;
  size_group: string;
};

// Customer
export interface Customer {
  id: number;
  name: string;
}

// Agent
export interface Agent {
  id: number;
  username: string;
}

// Item (from ItemSerializer)
export interface Item {
  id: number;
  name: string;
  price: number;
  // add more fields if your ItemSerializer includes them
}

// Order Item
export interface OrderItem {
  id: number;
  order: number;
  item: Item;
  variant: number;
  size_group: string;
  quantity: number;
  packed_quantity: number;
}

// Invoice Response
export interface InvoiceResponse {
  id: number;
  customer: Customer;
  agent: Agent;
  created_at: string; // ISO date string
  status: "PENDING" | "PACKED" | "DISPATCHED";
  items: OrderItem[];
  total_price: number;
}
