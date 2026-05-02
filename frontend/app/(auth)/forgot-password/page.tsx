"use client";
// app/forgot-password/page.tsx
// Place at:  src/app/forgot-password/page.tsx

import { Input } from "@/components/ui/input";
import { Field, FieldLabel } from "@/components/ui/field";
import { authApi } from "@/lib/api";
import {
  AlertCircle,
  ArrowLeft,
  CheckCircle2,
  Package,
  Send,
} from "lucide-react";
import Link from "next/link";
import { KeyboardEvent, useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";

type Status = "idle" | "loading" | "success" | "error";

export default function ForgotPassword() {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<Status>("idle");
  const [errorMsg, setErrorMsg] = useState("");
  const [shake, setShake] = useState(false);
  const emailRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    emailRef.current?.focus();
  }, []);

  const triggerShake = () => {
    setShake(false);
    requestAnimationFrame(() => setShake(true));
  };

  const handleSubmit = async () => {
    setErrorMsg("");
    if (!email.trim()) {
      setErrorMsg("Please enter your email address.");
      triggerShake();
      return;
    }

    setStatus("loading");
    try {
      await authApi.forgotPassword({ email: email.trim().toLowerCase() });
      setStatus("success");
    } catch (err: any) {
      setStatus("error");
      const msg =
        err?.response?.data?.error ?? "Something went wrong. Please try again.";
      setErrorMsg(msg);
      triggerShake();
    }
  };

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "Enter") handleSubmit();
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
                Check your inbox
              </p>
              <p className="text-sm text-[var(--color-text)] mt-1">
                If{" "}
                <span className="font-medium text-[var(--color-heading)]">
                  {email}
                </span>{" "}
                is linked to an account, you'll receive a reset link shortly.
              </p>
            </div>
            <p className="text-xs text-gray-400">
              Didn't get it? Check your spam folder or{" "}
              <button
                className="underline text-[var(--color-primary)] hover:opacity-70 transition-opacity"
                onClick={() => {
                  setStatus("idle");
                  setEmail("");
                }}
              >
                try again
              </button>
              .
            </p>
          </div>
        ) : (
          /* ── Form state ── */
          <>
            <div className="flex flex-col gap-1">
              <h2 className="text-lg font-semibold text-[var(--color-heading)]">
                Forgot your password?
              </h2>
              <p className="text-sm text-[var(--color-text)]">
                Enter your email and we'll send you a reset link.
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
                <p className="font-medium leading-snug">{errorMsg}</p>
              </div>
            )}

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
                  onKeyDown={handleKeyDown}
                  aria-invalid={!!errorMsg}
                  className={cn(
                    errorMsg && "border-red-400 bg-red-50 focus:ring-red-200",
                  )}
                />
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
                    Sending…
                  </>
                ) : (
                  <>
                    <Send size={16} />
                    Send reset link
                  </>
                )}
              </button>
            </div>
          </>
        )}

        {/* Back to login */}
        <Link
          href="/"
          className="flex items-center justify-center gap-1.5 text-sm text-[var(--color-text)] hover:text-[var(--color-primary)] transition-colors"
        >
          <ArrowLeft size={14} />
          Back to sign in
        </Link>
      </div>
    </div>
  );
}
