"use client";

import { AuthUser, LoginResponse } from "@/types/auth";
import { createContext, useContext, useState } from "react";

type AuthContextType = {
  user: AuthUser | null;
  accessToken: string | null;
  refreshToken: string | null;
  isAuthenticated: boolean;

  login: (data: LoginResponse) => void;
  logout: () => void;
};

const AuthContext = createContext<AuthContextType | null>(null);

const STORAGE_KEYS = {
  user: "auth_user",
  access: "auth_access",
  refresh: "auth_refresh",
};

const getStoredUser = (): AuthUser | null => {
  if (typeof window === "undefined") return null;
  const user = localStorage.getItem(STORAGE_KEYS.user);
  return user ? JSON.parse(user) : null;
};

const getStoredToken = (key: string): string | null => {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(key);
};

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(() => getStoredUser());
  const [accessToken, setAccessToken] = useState<string | null>(() =>
    getStoredToken(STORAGE_KEYS.access),
  );
  const [refreshToken, setRefreshToken] = useState<string | null>(() =>
    getStoredToken(STORAGE_KEYS.refresh),
  );

  const login = (data: LoginResponse) => {
    const authUser: AuthUser = {
      id: data.user_id,
      role: data.role,
    };

    setUser(authUser);
    setAccessToken(data.access);
    setRefreshToken(data.refresh);

    localStorage.setItem(STORAGE_KEYS.user, JSON.stringify(authUser));
    localStorage.setItem(STORAGE_KEYS.access, data.access);
    localStorage.setItem(STORAGE_KEYS.refresh, data.refresh);
  };

  const logout = () => {
    setUser(null);
    setAccessToken(null);
    setRefreshToken(null);

    localStorage.removeItem(STORAGE_KEYS.user);
    localStorage.removeItem(STORAGE_KEYS.access);
    localStorage.removeItem(STORAGE_KEYS.refresh);
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        accessToken,
        refreshToken,
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
