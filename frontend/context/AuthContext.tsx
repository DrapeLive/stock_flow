"use client";

import { AuthUser, LoginResponse, Business } from "@/types/auth";
import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
} from "react";
import Cookies from "js-cookie";
import { useRouter } from "next/navigation";
import { api } from "@/lib/api/axios";

type AuthContextType = {
  user: AuthUser | null;
  accessToken: string | null;
  refreshToken: string | null;
  role: string | null;
  business: Business | null;
  isSuperuser: boolean;
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
  business: "business",
  isSuperuser: "is_superuser",
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
  const [business, setBusiness] = useState<Business | null>(() => {
    if (typeof window === "undefined") return null;
    const val = Cookies.get(COOKIE_KEYS.business);
    return (val as Business | null) || null;
  });
  const [isSuperuser, setIsSuperuser] = useState<boolean>(() => {
    if (typeof window === "undefined") return false;
    return Cookies.get(COOKIE_KEYS.isSuperuser) === "true";
  });

  const login = (data: LoginResponse) => {
    const authUser: AuthUser = {
      id: data.user_id,
      role: data.role,
      username: (data as any).username,
      email: (data as any).email,
      business: data.business || null,
      is_superuser: data.is_superuser,
    };

    setUser(authUser);
    setAccessToken(data.access);
    setRefreshToken(data.refresh);
    setRole(data.role);
    setBusiness(data.business || null);
    setIsSuperuser(data.is_superuser);

    Cookies.set(COOKIE_KEYS.user, JSON.stringify(authUser));
    Cookies.set(COOKIE_KEYS.access, data.access);
    Cookies.set(COOKIE_KEYS.refresh, data.refresh);
    Cookies.set(COOKIE_KEYS.role, data.role);
    if (data.business) {
      Cookies.set(COOKIE_KEYS.business, data.business);
    }
    Cookies.set(COOKIE_KEYS.isSuperuser, String(data.is_superuser));
  };

  const logout = useCallback(() => {
    setUser(null);
    setAccessToken(null);
    setRefreshToken(null);
    setRole(null);
    setBusiness(null);
    setIsSuperuser(false);

    Cookies.remove(COOKIE_KEYS.user);
    Cookies.remove(COOKIE_KEYS.access);
    Cookies.remove(COOKIE_KEYS.refresh);
    Cookies.remove(COOKIE_KEYS.role);
    Cookies.remove(COOKIE_KEYS.business);
    Cookies.remove(COOKIE_KEYS.isSuperuser);

    router.push("/");
  }, [router]);

  useEffect(() => {
    const responseInterceptor = api.interceptors.response.use(
      (response) => response,
      (error) => {
        if (error.response?.status === 401) {
          logout();
        }
        return Promise.reject(error);
      },
    );

    return () => {
      api.interceptors.response.eject(responseInterceptor);
    };
  }, [logout]);

  useEffect(() => {
    if (accessToken === null && role === null) return;

    const pathname = window.location.pathname;

    if (!accessToken) {
      if (pathname !== "/") {
        router.replace("/");
      }
      return;
    }

    if (accessToken) {
      if (pathname === "/") {
        if (role === "ADMIN") {
          router.replace("/admin");
        } else {
          router.replace("/agent");
        }
        return;
      }

      if (pathname.startsWith("/admin") && role !== "ADMIN") {
        router.replace("/agent");
      }
    }
  }, [accessToken, role, router]);

  return (
    <AuthContext.Provider
      value={{
        user,
        accessToken,
        refreshToken,
        role,
        business,
        isSuperuser,
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
