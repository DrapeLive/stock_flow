"use client";

import { Input } from "@/components/ui/input";
import { Field, FieldLabel } from "@/components/ui/field";
import { authApi } from "@/lib/api";
import {
  AlertCircle,
  ArrowLeft,
  CheckCircle2,
  Eye,
  EyeOff,
  KeyRound,
  Package,
} from "lucide-react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useRef, useState, Suspense } from "react";
import { cn } from "@/lib/utils";

type Status = "idle" | "loading" | "success" | "error";

function ResetPasswordForm() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const token = searchParams.get("token") ?? "";

  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [status, setStatus] = useState<Status>("idle");
  const [errorMsg, setErrorMsg] = useState("");
  const [fieldErrors, setFieldErrors] = useState({ password: "", confirm: "" });
  const [shake, setShake] = useState(false);
  const passwordRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!token) {
      setErrorMsg("Invalid or missing reset link. Please request a new one.");
      setStatus("error");
    } else {
      passwordRef.current?.focus();
    }
  }, [token]);

  const triggerShake = () => {
    setShake(false);
    requestAnimationFrame(() => setShake(true));
  };

  const validate = (): boolean => {
    const errs = { password: "", confirm: "" };
    if (!password) errs.password = "Password is required.";
    else if (password.length < 8)
      errs.password = "Must be at least 8 characters.";
    if (!confirm) errs.confirm = "Please confirm your password.";
    else if (password !== confirm) errs.confirm = "Passwords do not match.";

    if (errs.password || errs.confirm) {
      setFieldErrors(errs);
      triggerShake();
      return false;
    }
    return true;
  };

  const handleSubmit = async () => {
    setErrorMsg("");
    setFieldErrors({ password: "", confirm: "" });
    if (!validate()) return;

    setStatus("loading");
    try {
      await authApi.resetPassword({ token, password });
      setStatus("success");
    } catch (err: any) {
      setStatus("error" as Status);
      const msg =
        err?.response?.data?.error ?? "Something went wrong. Please try again.";
      setErrorMsg(msg);
      triggerShake();
      setStatus("idle");
    }
  };

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

        {status === "success" ? (
          /* ── Success state ── */
          <div className="flex flex-col items-center gap-4 text-center">
            <div className="w-14 h-14 rounded-full bg-green-50 flex items-center justify-center">
              <CheckCircle2 size={30} className="text-green-500" />
            </div>
            <div>
              <p className="font-semibold text-[var(--color-heading)] text-base">
                Password updated!
              </p>
              <p className="text-sm text-[var(--color-text)] mt-1">
                Your password has been reset successfully. You can now sign in
                with your new password.
              </p>
            </div>
            <button
              type="button"
              onClick={() => router.replace("/")}
              className={cn(
                "w-full flex items-center justify-center gap-2 py-3.5 rounded-xl text-base font-medium text-white transition-all",
                "bg-[var(--color-primary)] hover:opacity-90 active:scale-[0.98]",
              )}
            >
              Go to sign in
            </button>
          </div>
        ) : (
          /* ── Form state ── */
          <>
            <div className="flex flex-col gap-1">
              <h2 className="text-lg font-semibold text-[var(--color-heading)]">
                Set a new password
              </h2>
              <p className="text-sm text-[var(--color-text)]">
                Must be at least 8 characters long.
              </p>
            </div>

            {/* Error alert */}
            {errorMsg && (
              <div
                role="alert"
                aria-live="assertive"
                className="flex items-center gap-3 rounded-xl px-4 py-3 text-sm border bg-red-50 border-red-200 text-red-700"
              >
                <AlertCircle
                  size={16}
                  className="mt-0.5 shrink-0 text-red-400"
                />
                <div>
                  <p className="font-medium leading-snug">{errorMsg}</p>
                  {errorMsg.toLowerCase().includes("expired") ||
                  errorMsg.toLowerCase().includes("invalid") ? (
                    <Link
                      href="/forgot-password"
                      className="text-xs mt-0.5 underline opacity-80 hover:opacity-100"
                    >
                      Request a new link
                    </Link>
                  ) : null}
                </div>
              </div>
            )}

            <div className="flex flex-col gap-5">
              {/* New Password */}
              <Field>
                <FieldLabel htmlFor="password">New password</FieldLabel>
                <div className="relative flex items-center">
                  <Input
                    ref={passwordRef}
                    id="password"
                    type={showPassword ? "text" : "password"}
                    placeholder="At least 8 characters"
                    autoComplete="new-password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter")
                        document.getElementById("confirm")?.focus();
                    }}
                    aria-invalid={!!fieldErrors.password}
                    className={cn(
                      "pr-10",
                      fieldErrors.password &&
                        "border-red-400 bg-red-50 focus:ring-red-200",
                    )}
                  />
                  <button
                    type="button"
                    tabIndex={-1}
                    aria-label={
                      showPassword ? "Hide password" : "Show password"
                    }
                    onClick={() => setShowPassword((v) => !v)}
                    className="absolute right-3 text-gray-400 hover:text-gray-600 transition-colors"
                  >
                    {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
                {fieldErrors.password && (
                  <p className="text-xs text-red-500 mt-1">
                    {fieldErrors.password}
                  </p>
                )}
              </Field>

              {/* Confirm Password */}
              <Field>
                <FieldLabel htmlFor="confirm">Confirm new password</FieldLabel>
                <div className="relative flex items-center">
                  <Input
                    id="confirm"
                    type={showConfirm ? "text" : "password"}
                    placeholder="Re-enter your password"
                    autoComplete="new-password"
                    value={confirm}
                    onChange={(e) => setConfirm(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") handleSubmit();
                    }}
                    aria-invalid={!!fieldErrors.confirm}
                    className={cn(
                      "pr-10",
                      fieldErrors.confirm &&
                        "border-red-400 bg-red-50 focus:ring-red-200",
                    )}
                  />
                  <button
                    type="button"
                    tabIndex={-1}
                    aria-label={showConfirm ? "Hide password" : "Show password"}
                    onClick={() => setShowConfirm((v) => !v)}
                    className="absolute right-3 text-gray-400 hover:text-gray-600 transition-colors"
                  >
                    {showConfirm ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
                {fieldErrors.confirm && (
                  <p className="text-xs text-red-500 mt-1">
                    {fieldErrors.confirm}
                  </p>
                )}
              </Field>

              <button
                type="button"
                disabled={status === "loading"}
                onClick={handleSubmit}
                className={cn(
                  "w-full flex items-center justify-center gap-2 py-3.5 rounded-xl text-base font-medium text-white transition-all",
                  "bg-[var(--color-primary)] hover:opacity-90 active:scale-[0.98]",
                  "disabled:opacity-60 disabled:cursor-not-allowed",
                )}
              >
                {status === "loading" ? (
                  <>
                    <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                    Updating…
                  </>
                ) : (
                  <>
                    <KeyRound size={16} />
                    Reset password
                  </>
                )}
              </button>
            </div>
          </>
        )}

        {/* Back to login */}
        {status !== "success" && (
          <Link
            href="/login"
            className="flex items-center justify-center gap-1.5 text-sm text-[var(--color-text)] hover:text-[var(--color-primary)] transition-colors"
          >
            <ArrowLeft size={14} />
            Back to sign in
          </Link>
        )}
      </div>
    </div>
  );
}

// Wrap in Suspense because useSearchParams() needs it in Next.js 14+
export default function ResetPasswordPage() {
  return (
    <Suspense>
      <ResetPasswordForm />
    </Suspense>
  );
}
