import { LoginRequest, LoginResponse } from "@/types/auth";
import { api, setAccessToken } from "./axios";

export const authApi = {
  async login(data: LoginRequest): Promise<LoginResponse> {
    const res = await api.post<LoginResponse>("/api/auth/login/", data);
    setAccessToken(res.data.access);

    return res.data;
  },

  logout() {
    setAccessToken(null);
  },
};
