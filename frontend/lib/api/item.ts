import { api } from "./axios";
import { ItemAllResponse, ItemRequest, ItemResponse } from "@/types/item";

export const itemApi = {
  async getAll(): Promise<ItemAllResponse> {
    const res = await api.get<ItemAllResponse>("/api/items/");
    return res.data;
  },

  async getOne(id: number | undefined): Promise<ItemResponse> {
    const res = await api.get<ItemResponse>(`/api/items/${id}`);
    return res.data;
  },

  async create(data: ItemRequest | FormData): Promise<ItemResponse> {
    const res = await api.post<ItemResponse>("/api/items/", data, {
      headers:
        data instanceof FormData
          ? { "Content-Type": "multipart/form-data" }
          : undefined,
    });
    return res.data;
  },

  async byqr(id: string): Promise<ItemResponse> {
    const res = await api.get<ItemResponse>(`/api/items/by-qr/?qr_code=${id}`);
    return res.data;
  },
};
