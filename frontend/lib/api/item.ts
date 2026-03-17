import { api } from "./axios";
import {
  ItemAllResponse,
  ItemQRResponse,
  ItemRequest,
  ItemResponse,
} from "@/types/item";

export const itemApi = {
  async getAll(): Promise<ItemAllResponse> {
    const res = await api.get<ItemAllResponse>("/api/items/");
    return res.data;
  },

  async getOne(id: number | undefined): Promise<ItemResponse> {
    const res = await api.get<ItemResponse>(`/api/items/${id}`);
    return res.data;
  },

  async create(
    data: ItemRequest | FormData | Record<string, unknown>,
  ): Promise<ItemResponse> {
    const res = await api.post<ItemResponse>("/api/items/", data, {
      headers:
        data instanceof FormData
          ? { "Content-Type": "multipart/form-data" }
          : { "Content-Type": "application/json" },
    });
    return res.data;
  },

  async byqr(id: string): Promise<ItemQRResponse> {
    const res = await api.get<ItemQRResponse>(
      `/api/items/by-qr/?qr_code=${id}`,
    );
    return res.data;
  },

  async update(
    id: number,
    data: ItemRequest | FormData,
  ): Promise<ItemResponse> {
    const res = await api.put<ItemResponse>(`/api/items/${id}/`, data, {
      headers:
        data instanceof FormData
          ? { "Content-Type": "multipart/form-data" }
          : undefined,
    });
    return res.data;
  },

  async delete(id: number): Promise<void> {
    await api.delete(`/api/items/${id}/`);
  },
};
