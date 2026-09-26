import axios from "axios";
import Cookies from "js-cookie";

// const API_BASE_URL =
//   process.env.NEXT_PUBLIC_API_BASE_URL ?? "https://stock-flow-tnwn.onrender.com";

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";

export const api = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: false,
  headers: {
    "Content-Type": "application/json",
    "ngrok-skip-browser-warning": "true",
  },
});

export function clearFormDataContentType(config: {
  data?: unknown;
  headers: { delete: (name: string) => void };
}): void {
  if (config.data instanceof FormData) {
    config.headers.delete("Content-Type");
  }
}

api.interceptors.request.use((config) => {
  clearFormDataContentType(config);

  if (typeof window !== "undefined") {
    const accessToken = Cookies.get("token");

    if (accessToken) {
      config.headers.Authorization = `Bearer ${accessToken}`;
    }
  }

  return config;
});
