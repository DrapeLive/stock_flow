import { api } from "./axios";
import { ItemAllResponse } from "@/types/item";

export const itemApi = {
  async getAll(): Promise<ItemAllResponse> {
    const res = await api.get<ItemAllResponse>("/api/items/");
    return res.data;
  },
};
