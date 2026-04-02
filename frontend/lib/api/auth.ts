import { LoginRequest, LoginResponse, UserProfile } from "@/types/auth";
import { api } from "./axios";

export const authApi = {
  async login(data: LoginRequest): Promise<LoginResponse> {
    const res = await api.post<LoginResponse>("/api/auth/login/", data);

    return res.data;
  },

  async getProfile(): Promise<UserProfile> {
    const res = await api.get<UserProfile>("/api/auth/profile/");
    return res.data;
  },

  logout() {},
};
