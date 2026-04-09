"use client";

import { AuthUser, LoginResponse } from "@/types/auth";
import { createContext, useContext, useState, useEffect, useCallback } from "react";
import Cookies from "js-cookie";
import { useRouter } from "next/navigation";
import { api } from "@/lib/api/axios";

type AuthContextType = {
  user: AuthUser | null;
  accessToken: string | null;
  refreshToken: string | null;
  role: string | null; // Add role to the context type
  isAuthenticated: boolean;

  login: (data: LoginResponse) => void;
  logout: () => void;
};

const AuthContext = createContext<AuthContextType | null>(null);

const COOKIE_KEYS = {
  user: "auth_user",
  access: "token",
  refresh: "auth_refresh",
  role: "role",
};

const getStoredUser = (): AuthUser | null => {
  if (typeof window === "undefined") return null;
  const user = Cookies.get(COOKIE_KEYS.user);
  return user ? JSON.parse(user) : null;
};

const getStoredToken = (key: string): string | null => {
  if (typeof window === "undefined") return null;
  return Cookies.get(key) || null;
};

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const [user, setUser] = useState<AuthUser | null>(() => getStoredUser());
  const [accessToken, setAccessToken] = useState<string | null>(() =>
    getStoredToken(COOKIE_KEYS.access),
  );
  const [refreshToken, setRefreshToken] = useState<string | null>(() =>
    getStoredToken(COOKIE_KEYS.refresh),
  );
  const [role, setRole] = useState<string | null>(() =>
    getStoredToken(COOKIE_KEYS.role),
  );

  const login = (data: LoginResponse) => {
    const authUser: AuthUser = {
      id: data.user_id,
      role: data.role,
      username: (data as any).username,
      email: (data as any).email,
    };

    setUser(authUser);
    setAccessToken(data.access);
    setRefreshToken(data.refresh);
    setRole(data.role);

    Cookies.set(COOKIE_KEYS.user, JSON.stringify(authUser));
    Cookies.set(COOKIE_KEYS.access, data.access);
    Cookies.set(COOKIE_KEYS.refresh, data.refresh);
    Cookies.set(COOKIE_KEYS.role, data.role);
  };

  const logout = useCallback(() => {
    setUser(null);
    setAccessToken(null);
    setRefreshToken(null);
    setRole(null);

    Cookies.remove(COOKIE_KEYS.user);
    Cookies.remove(COOKIE_KEYS.access);
    Cookies.remove(COOKIE_KEYS.refresh);
    Cookies.remove(COOKIE_KEYS.role);

    router.push("/login");
  }, [router]);

  useEffect(() => {
    const responseInterceptor = api.interceptors.response.use(
      (response) => response,
      (error) => {
        if (error.response?.status === 401) {
          logout();
        }
        return Promise.reject(error);
      }
    );

    return () => {
      api.interceptors.response.eject(responseInterceptor);
    };
  }, [logout]);

  return (
    <AuthContext.Provider
      value={{
        user,
        accessToken,
        refreshToken,
        role, // Include role in the context value
        isAuthenticated: !!accessToken,
        login,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAuth must be used inside AuthProvider");
  }
  return ctx;
}
