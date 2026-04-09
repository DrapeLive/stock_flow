"use client";

import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { Field, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { useAuth } from "@/context/AuthContext";
import { authApi } from "@/lib/api";
import { toastError } from "@/lib/toast";
import { LogIn, Package } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

export default function Login() {
  const { login, isAuthenticated, user } = useAuth();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const router = useRouter();

  useEffect(() => {
    if (isAuthenticated) {
      if (user?.role === "ADMIN") router.push("/admin");
      else router.push("/");
    }
  }, [isAuthenticated, user, router]);

  const handleLogin = async () => {
    setLoading(true);

    try {
      const res = await authApi.login({
        email,
        password,
      });

      login(res);
    } catch (err) {
      toastError("Invalid email or password", err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen min-w-full bg-gray-50 justify-center items-center px-6 py-10">
      <div className="w-full max-w-sm bg-white shadow-xl rounded-3xl px-8 py-10 flex flex-col gap-8">
        {/* Branding */}
        <div className="flex flex-col items-center gap-3">
          <div className="w-14 h-14 rounded-2xl bg-[var(--color-primary)] flex items-center justify-center shadow-lg">
            <Package size={28} className="text-white" />
          </div>
          <div className="text-center">
            <h1 className="text-2xl font-bold text-[var(--color-heading)] mb-0">
              StockFlow
            </h1>
            <p className="text-[11px] text-[var(--color-text)] uppercase tracking-widest font-medium">
              Order Management
            </p>
          </div>
        </div>

        {/* Form */}
        <div className="flex flex-col gap-5">
          <Field>
            <FieldLabel htmlFor="email">Email Address</FieldLabel>
            <Input
              id="email"
              type="text"
              placeholder="example@gmail.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </Field>
          <Field>
            <FieldLabel htmlFor="password">Password</FieldLabel>
            <Input
              id="password"
              type="password"
              placeholder="Enter your password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </Field>

          <StockFlowButton
            variant="filled"
            text={loading ? "Signing in..." : "Sign In"}
            icon={<LogIn size={18} />}
            onClick={handleLogin}
            disabled={loading}
            className="w-full justify-center py-3.5 rounded-xl text-base mt-1"
          />
        </div>
      </div>
    </div>
  );
}
