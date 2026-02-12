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

  async create(data: ItemRequest): Promise<ItemResponse> {
    const res = await api.post<ItemResponse>("/api/items/", data);
    return res.data;
  },
};
