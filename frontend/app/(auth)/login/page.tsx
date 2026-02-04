"use client";

import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { Field, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { useAuth } from "@/context/AuthContext";
import { LogIn } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

export default function Login() {
  const { login, isAuthenticated, user } = useAuth();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const router = useRouter();

  useEffect(() => {
    if (isAuthenticated) {
      if (user?.role === "ADMIN") router.push("/admin");
      else router.push("/agent");
    }
  }, [isAuthenticated, user, router]);

  const handleLogin = async () => {
    setLoading(true);
    setError(null);

    try {
      const res = await loginApi({
        email,
        password,
      });

      login(res.data); // 🔥 this updates AuthContext
    } catch (err) {
      setError("Invalid email or password");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen min-w-full py-6 px-6 justify-center items-center">
      <div className="flex flex-col w-full gap-16">
        <h2 className="flex text-4xl w-full justify-center text-(--color-primary)">
          Login
        </h2>
        <div className="flex flex-col gap-6">
          <Field>
            <FieldLabel>Email</FieldLabel>
            <Input
              type="text"
              placeholder="example@gmail.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            ></Input>
          </Field>
          <Field>
            <FieldLabel>Password</FieldLabel>
            <Input
              type="password"
              placeholder="*****"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            ></Input>
          </Field>

          {error && <p className="text-sm text-red-500 text-center">{error}</p>}

          <div className="flex justify-center gap-2.5">
            <StockFlowButton
              variant="filled"
              text={loading ? "Logging in..." : "Login"}
              icon={<LogIn />}
              onClick={handleLogin}
              disabled={loading}
            />
          </div>
        </div>
      </div>
    </div>
  );
}
