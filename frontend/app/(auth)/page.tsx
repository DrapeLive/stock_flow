"use client";
import { Field, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { useAuth } from "@/context/AuthContext";
import { authApi } from "@/lib/api";
import {
  LogIn,
  Package,
  AlertCircle,
  AlertTriangle,
  Eye,
  EyeOff,
} from "lucide-react";
import { useRouter } from "next/navigation";
import { useState, useEffect, useRef, KeyboardEvent } from "react";
import { cn } from "@/lib/utils"; // adjust to your cn utility path

type ErrorType =
  | "network"
  | "cors"
  | "wrong_password"
  | "no_account"
  | "generic"
  | null;

const ERROR_MESSAGES: Record<
  NonNullable<ErrorType>,
  { title: string; sub?: string; warn?: boolean }
> = {
  network: {
    title: "No internet connection",
    sub: "Check your connection and try again.",
  },
  cors: {
    title: "Cannot reach the server",
    sub: "This may be a network or CORS issue — contact your admin if this persists.",
    warn: true,
  },
  wrong_password: {
    title: "Wrong password",
    sub: "Double-check your password and try again.",
  },
  no_account: {
    title: "No account found for this email",
  },
  generic: {
    title: "Sign-in failed",
    sub: "Something went wrong. Please try again.",
  },
};

function classifyError(err: any): NonNullable<ErrorType> {
  if (!err.response) {
    if (err.code === "200") {
      return "network";
    }
    return "cors";
  }

  const status: number = err.response.status;
  const serverMsg: string = (err.response?.data?.error ?? "").toLowerCase();

  if (status === 400 || status === 401) {
    if (
      serverMsg.includes("email") ||
      serverMsg.includes("not found") ||
      serverMsg.includes("no account")
    ) {
      return "no_account";
    }
    if (
      serverMsg.includes("password") ||
      serverMsg.includes("invalid credentials")
    ) {
      return "wrong_password";
    }
  }

  return "generic";
}
export default function Login() {
  const { login } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [errorType, setErrorType] = useState<ErrorType>(null);
  const [fieldErrors, setFieldErrors] = useState({ email: "", password: "" });
  const [shake, setShake] = useState(false);
  const router = useRouter();
  const emailRef = useRef<HTMLInputElement>(null);

  // Auto-focus email on mount
  useEffect(() => {
    emailRef.current?.focus();
  }, []);

  const triggerShake = () => {
    setShake(false);
    requestAnimationFrame(() => setShake(true));
  };

  const clearErrors = () => {
    setErrorType(null);
    setFieldErrors({ email: "", password: "" });
  };

  const validate = (): boolean => {
    const errs = { email: "", password: "" };
    if (!email.trim()) errs.email = "Email is required";
    if (!password) errs.password = "Password is required";
    if (errs.email || errs.password) {
      setFieldErrors(errs);
      triggerShake();
      return false;
    }
    return true;
  };

  const handleLogin = async () => {
    clearErrors();
    if (!validate()) return;

    setLoading(true);
    try {
      const res = await authApi.login({ email, password });
      login(res);
      router.replace(res.role === "ADMIN" ? "/admin" : "/agent");
    } catch (err: any) {
      setErrorType(classifyError(err));
      triggerShake();
    } finally {
      setLoading(false);
    }
  };

  const handleKeyDown = (e: KeyboardEvent, field: "email" | "password") => {
    if (e.key !== "Enter") return;
    if (field === "email") {
      document.getElementById("password")?.focus();
    } else {
      handleLogin();
    }
  };
  const error = errorType ? ERROR_MESSAGES[errorType] : null;

  return (
    <div className="flex min-h-screen min-w-full bg-gray-50 justify-center items-center px-6 py-10">
      <div
        className={cn(
          "w-full max-w-sm bg-white shadow-xl rounded-3xl px-8 py-10 flex flex-col gap-8",
          shake && "animate-shake",
        )}
        onAnimationEnd={() => setShake(false)}
      >
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

        {/* Inline error alert */}
        {error && (
          <div
            role="alert"
            aria-live="assertive"
            className={cn(
              "flex items-center gap-3 rounded-xl px-4 py-3 text-sm border",
              error.warn
                ? "bg-amber-50 border-amber-200 text-amber-800"
                : "bg-red-50 border-red-200 text-red-700",
            )}
          >
            {error.warn ? (
              <AlertTriangle
                size={16}
                className="mt-0.5 shrink-0 text-amber-500"
              />
            ) : (
              <AlertCircle size={16} className="mt-0.5 shrink-0 text-red-400" />
            )}
            <div>
              <p className="font-medium leading-snug text-sm">{error.title}</p>
              {error.sub && (
                <p className="text-xs mt-0.5 opacity-80">{error.sub}</p>
              )}
            </div>
          </div>
        )}

        {/* Form */}
        <div className="flex flex-col gap-5">
          <Field>
            <FieldLabel htmlFor="email">Email address</FieldLabel>
            <Input
              ref={emailRef}
              id="email"
              type="email"
              placeholder="example@gmail.com"
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              onKeyDown={(e) => handleKeyDown(e, "email")}
              aria-invalid={!!fieldErrors.email}
              aria-describedby={fieldErrors.email ? "email-error" : undefined}
              className={cn(
                fieldErrors.email &&
                  "border-red-400 bg-red-50 focus:ring-red-200",
              )}
            />
            {fieldErrors.email && (
              <p id="email-error" className="text-xs text-red-500 mt-1">
                {fieldErrors.email}
              </p>
            )}
          </Field>

          <Field>
            <FieldLabel htmlFor="password">Password</FieldLabel>
            <div className="relative flex items-center">
              <Input
                id="password"
                type={showPassword ? "text" : "password"}
                placeholder="Enter your password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                onKeyDown={(e) => handleKeyDown(e, "password")}
                aria-invalid={!!fieldErrors.password}
                aria-describedby={fieldErrors.password ? "pw-error" : undefined}
                className={cn(
                  "pr-10",
                  fieldErrors.password &&
                    "border-red-400 bg-red-50 focus:ring-red-200",
                )}
              />
              <button
                type="button"
                tabIndex={-1}
                aria-label={showPassword ? "Hide password" : "Show password"}
                onClick={() => setShowPassword((v) => !v)}
                className="absolute right-3 text-gray-400 hover:text-gray-600 transition-colors"
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
            {fieldErrors.password && (
              <p id="pw-error" className="text-xs text-red-500 mt-1">
                {fieldErrors.password}
              </p>
            )}
          </Field>

          <button
            type="button"
            disabled={loading}
            onClick={handleLogin}
            className={cn(
              "w-full flex items-center justify-center gap-2 py-3.5 rounded-xl text-base font-medium text-white transition-all",
              "bg-[var(--color-primary)] hover:opacity-90 active:scale-[0.98]",
              "disabled:opacity-60 disabled:cursor-not-allowed",
            )}
          >
            {loading ? (
              <>
                <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                Signing in…
              </>
            ) : (
              <>
                <LogIn size={18} />
                Sign in
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
