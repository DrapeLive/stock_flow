"use client";

import { createContext, useContext, useState } from "react";

type AuthContextType = {
  user: any;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
};

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState(null);

  const login = async (email: string, password: string) => {
    const res = await fetch("http://localhost:8000/auth/login/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username: email, password }),
    });

    if (!res.ok) throw new Error("Login failed");

    const data = await res.json();

    // store token securely
    document.cookie = `access=${data.access}; path=/`;
    document.cookie = `refresh=${data.refresh}; path=/`;

    setUser({ email });
  };

  const logout = () => {
    document.cookie = "access=; Max-Age=0";
    document.cookie = "refresh=; Max-Age=0";
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext)!;
