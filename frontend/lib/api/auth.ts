import { LoginRequest, LoginResponse } from "@/types/auth";
import { api } from "./axios";

export const authApi = {
  async login(data: LoginRequest): Promise<LoginResponse> {
    const res = await api.post<LoginResponse>("/api/auth/login/", data);

    return res.data;
  },

  logout() {},
};
