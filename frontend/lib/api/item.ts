import type {
  ItemAllResponse,
  ItemResponse,
  ItemRequest,
  ItemQRResponse,
  VariantAllResponse,
  ItemStockEntry,
} from "@/types/item";
import { api } from "./axios";

export const itemApi = {
  getAll(): Promise<ItemAllResponse> {
    return api.get<ItemAllResponse>("/api/items/").then((r) => r.data);
  },

  getAllVariants(): Promise<VariantAllResponse> {
    return api.get<VariantAllResponse>("/api/items/variants/all/").then((r) => r.data);
  },

  getStockList(): Promise<ItemStockEntry[]> {
    return api.get<ItemStockEntry[]>("/api/items/stock-list/").then((r) => r.data);
  },

  getOne(id: number): Promise<ItemResponse> {
    return api.get<ItemResponse>(`/api/items/${id}/`).then((r) => r.data);
  },

  create(data: ItemRequest | FormData): Promise<ItemResponse> {
    const headers =
      data instanceof FormData
        ? { "Content-Type": "multipart/form-data" }
        : { "Content-Type": "application/json" };
    return api
      .post<ItemResponse>("/api/items/", data, { headers })
      .then((r) => r.data);
  },

  byqr(qrCode: string): Promise<ItemQRResponse> {
    return api
      .get<ItemQRResponse>(`/api/items/by-qr/?qr_code=${qrCode}`)
      .then((r) => r.data);
  },

  update(id: number, data: ItemRequest | FormData): Promise<ItemResponse> {
    const headers =
      data instanceof FormData
        ? { "Content-Type": "multipart/form-data" }
        : undefined;
    return api
      .put<ItemResponse>(`/api/items/${id}/`, data, { headers })
      .then((r) => r.data);
  },

  delete(id: number): Promise<void> {
    return api.delete(`/api/items/${id}/`).then((r) => r.data);
  },
};
