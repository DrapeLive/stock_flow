"use client";

import { orderApi } from "@/lib/api/order";
import { InvoiceResponse } from "@/types/order";
import { useRouter } from "next/navigation";
import { useRef, useEffect, useState } from "react";

// ── Helpers ────────────────────────────────────────────────────────────────────
const formatDate = (iso: string) =>
  new Date(iso).toLocaleDateString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });

const formatTime = (iso: string) =>
  new Date(iso).toLocaleTimeString("en-IN", {
    hour: "2-digit",
    minute: "2-digit",
  });

const statusStyles: Record<InvoiceResponse["status"], string> = {
  PENDING:
    "bg-amber-50 text-amber-700 border border-amber-200 ring-1 ring-amber-300/40",
  DISPATCHED:
    "bg-emerald-50 text-emerald-700 border border-emerald-200 ring-1 ring-emerald-300/40",
  PACKED: "bg-red-50 text-red-700 border border-red-200 ring-1 ring-red-300/40",
};

// ── Page Component ─────────────────────────────────────────────────────────────
export default function InvoicePage() {
  const router = useRouter();
  const invoiceRef = useRef<HTMLDivElement>(null);

  const [invoice, setInvoice] = useState<InvoiceResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  // ── Fetch invoice on mount ──
  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      try {
        const key = localStorage.getItem("orderKey");
        if (key) {
          const res = await orderApi.invoiceOrder(Number(key));
          setInvoice(res);
        } else {
          setError(true);
        }
      } catch (e) {
        console.error("Error fetching order details:", e);
        setError(true);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  // ── WhatsApp share ──
  const buildWhatsAppMessage = (inv: InvoiceResponse) => {
    const lines = [
      `🧾 *Invoice #${inv.id.toString().padStart(4, "0")}*`,
      `📅 ${formatDate(inv.created_at)}`,
      `👤 Customer: ${inv.customer.name}`,
      `🛒 Items:`,
      ...inv.items.map(
        (oi) =>
          `  • ${oi.item.name} (${oi.size_group}) × ${oi.quantity} = ₹${(
            oi.item.price * oi.quantity
          ).toLocaleString("en-IN")}`,
      ),
      ``,
      `💰 *Total: ₹${inv.total_price.toLocaleString("en-IN")}*`,
      `📦 Status: ${inv.status}`,
    ];
    return encodeURIComponent(lines.join("\n"));
  };

  const handleShareWhatsApp = () => {
    if (!invoice) return;
    const text = buildWhatsAppMessage(invoice);
    window.open(`https://wa.me/?text=${text}`, "_blank");
    router.push("/");
  };

  // ── Loading state ──
  if (loading) {
    return (
      <main className="min-h-screen bg-slate-50 flex items-center justify-center">
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 rounded-full border-4 border-indigo-200 border-t-indigo-500 animate-spin" />
          <p className="text-sm text-slate-400">Loading invoice…</p>
        </div>
      </main>
    );
  }

  // ── Error / not found state ──
  if (error || !invoice) {
    return (
      <main className="min-h-screen bg-slate-50 flex items-center justify-center px-4">
        <div className="text-center">
          <p className="text-slate-500 mb-4">Failed to load invoice.</p>
          <button
            onClick={() => router.push("/")}
            className="text-sm text-indigo-600 hover:underline"
          >
            ← Go home
          </button>
        </div>
      </main>
    );
  }

  // ── Main render ──
  return (
    <main className="min-h-screen bg-slate-50 font-sans flex flex-col items-center py-10 px-4">
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Serif+Display&family=DM+Sans:wght@400;500;600&display=swap');
        body { font-family: 'DM Sans', sans-serif; }
        .font-display { font-family: 'DM Serif Display', serif; }
      `}</style>

      {/* ── Header ── */}
      <header className="w-full max-w-2xl flex items-center justify-between mb-6">
        <button
          onClick={() => router.push("/")}
          className="flex items-center gap-1.5 text-sm text-slate-500 hover:text-slate-800 transition-colors"
        >
          <svg
            className="w-4 h-4"
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M15 19l-7-7 7-7"
            />
          </svg>
          Back
        </button>
        <span className="text-xs text-slate-400 tracking-widest uppercase">
          Order Management
        </span>
      </header>

      {/* ── Invoice Card ── */}
      <div
        ref={invoiceRef}
        className="w-full max-w-2xl bg-white rounded-2xl shadow-xl shadow-slate-200/70 overflow-hidden border border-slate-100"
      >
        {/* Top accent bar */}
        <div className="h-1.5 w-full bg-gradient-to-r from-indigo-500 via-violet-500 to-purple-500" />

        {/* ── Invoice Header ── */}
        <div className="px-8 pt-8 pb-6 flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4 border-b border-slate-100">
          <div>
            <p className="text-xs font-semibold tracking-widest text-indigo-500 uppercase mb-1">
              Invoice
            </p>
            <h1 className="font-display text-4xl text-slate-800">
              #{invoice.id.toString().padStart(4, "0")}
            </h1>
            <p className="text-sm text-slate-400 mt-1">
              {formatDate(invoice.created_at)}&nbsp;·&nbsp;
              {formatTime(invoice.created_at)}
            </p>
          </div>

          <div className="flex flex-col items-start sm:items-end gap-2">
            <span
              className={`text-xs font-semibold px-3 py-1 rounded-full tracking-wide uppercase ${statusStyles[invoice.status]}`}
            >
              {invoice.status}
            </span>
            <div className="text-right">
              <p className="text-xs text-slate-400">Agent</p>
              <p className="text-sm font-medium text-slate-700">
                @{invoice.agent.username}
              </p>
            </div>
          </div>
        </div>

        {/* ── Bill To ── */}
        <div className="px-8 py-5 bg-slate-50/60 border-b border-slate-100">
          <p className="text-xs font-semibold text-slate-400 uppercase tracking-widest mb-1">
            Bill To
          </p>
          <p className="text-lg font-semibold text-slate-800">
            {invoice.customer.name}
          </p>
          <p className="text-xs text-slate-400">
            Customer ID: #{invoice.customer.id}
          </p>
        </div>

        {/* ── Items Table ── */}
        <div className="px-8 py-6">
          <div className="rounded-xl overflow-hidden border border-slate-100">
            {/* Table head */}
            <div className="grid grid-cols-12 bg-slate-800 text-white text-xs font-semibold uppercase tracking-wider px-4 py-3">
              <span className="col-span-4">Item</span>
              <span className="col-span-2 text-center">Size</span>
              <span className="col-span-2 text-center">Qty</span>
              <span className="col-span-2 text-center">Packed</span>
              <span className="col-span-2 text-right">Amount</span>
            </div>

            {/* Table rows */}
            {invoice.items.map((oi, idx) => (
              <div
                key={oi.id}
                className={`grid grid-cols-12 px-4 py-3.5 text-sm items-center border-t border-slate-100 ${
                  idx % 2 === 0 ? "bg-white" : "bg-slate-50"
                }`}
              >
                <div className="col-span-4">
                  <p className="font-medium text-slate-800">{oi.item.name}</p>
                  <p className="text-xs text-slate-400 mt-0.5">
                    ₹{oi.item.price.toLocaleString("en-IN")} / pc
                  </p>
                </div>
                <span className="col-span-2 text-center text-slate-500 text-xs font-mono bg-slate-100 rounded px-1.5 py-0.5 mx-auto">
                  {oi.size_group}
                </span>
                <span className="col-span-2 text-center font-semibold text-slate-700">
                  {oi.quantity}
                </span>
                <div className="col-span-2 flex justify-center">
                  <span
                    className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      oi.packed_quantity >= oi.quantity
                        ? "bg-emerald-100 text-emerald-700"
                        : "bg-orange-100 text-orange-600"
                    }`}
                  >
                    {oi.packed_quantity}/{oi.quantity}
                  </span>
                </div>
                <span className="col-span-2 text-right font-semibold text-slate-800">
                  ₹{(oi.item.price * oi.quantity).toLocaleString("en-IN")}
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* ── Totals ── */}
        <div className="px-8 pb-8">
          <div className="ml-auto w-full sm:w-72 rounded-xl bg-slate-50 border border-slate-100 overflow-hidden">
            <div className="flex justify-between px-5 py-3 text-sm text-slate-500 border-b border-slate-100">
              <span>Subtotal</span>
              <span className="font-medium text-slate-700">
                ₹{invoice.total_price.toLocaleString("en-IN")}
              </span>
            </div>
            <div className="flex justify-between px-5 py-3 text-sm text-slate-500 border-b border-slate-100">
              <span>Tax</span>
              <span className="font-medium text-slate-700">—</span>
            </div>
            <div className="flex justify-between px-5 py-4 bg-slate-800 text-white">
              <span className="font-semibold text-sm tracking-wide">Total</span>
              <span className="font-display text-xl">
                ₹{invoice.total_price.toLocaleString("en-IN")}
              </span>
            </div>
          </div>
        </div>

        {/* ── Footer note ── */}
        <div className="px-8 pb-6 text-center text-xs text-slate-300 border-t border-slate-100 pt-4">
          Generated automatically &nbsp;·&nbsp; Order #{invoice.id}{" "}
          &nbsp;·&nbsp; {formatDate(invoice.created_at)}
        </div>
      </div>

      {/* ── Share Button ── */}
      <div className="w-full max-w-2xl mt-6">
        <button
          onClick={handleShareWhatsApp}
          className="group w-full flex items-center justify-center gap-3 bg-[#25D366] hover:bg-[#1ebe5d] active:scale-[0.98] text-white font-semibold text-base py-4 rounded-2xl shadow-lg shadow-[#25D366]/30 transition-all duration-200"
        >
          <svg
            className="w-5 h-5"
            viewBox="0 0 32 32"
            fill="white"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path d="M16.002 2.667C8.638 2.667 2.667 8.637 2.667 16a13.283 13.283 0 0 0 1.784 6.667L2.667 29.333l6.867-1.77A13.266 13.266 0 0 0 16.002 29.333C23.365 29.333 29.333 23.363 29.333 16S23.365 2.667 16.002 2.667zm0 2.4c5.997 0 10.931 4.934 10.931 10.933 0 5.998-4.934 10.933-10.931 10.933a10.89 10.89 0 0 1-5.556-1.521l-.398-.239-4.075 1.049 1.076-3.959-.261-.41A10.887 10.887 0 0 1 5.07 16c0-5.999 4.934-10.933 10.932-10.933zm-3.29 5.266c-.198 0-.52.074-.792.37-.273.296-1.04 1.016-1.04 2.478 0 1.462 1.064 2.876 1.213 3.074.148.198 2.072 3.164 5.02 4.312 2.484.98 2.948.785 3.48.736.533-.05 1.72-.703 1.963-1.382.245-.679.245-1.261.172-1.382-.074-.12-.272-.197-.57-.345-.297-.148-1.756-.867-2.028-.965-.272-.1-.47-.148-.667.148-.198.297-.766.965-.94 1.163-.172.197-.345.222-.642.074-.297-.148-1.252-.462-2.384-1.47-.881-.784-1.476-1.752-1.649-2.048-.172-.297-.018-.457.13-.604.132-.132.296-.346.445-.519.148-.172.197-.297.296-.494.099-.198.05-.37-.025-.52-.074-.147-.659-1.614-.908-2.207-.24-.58-.485-.5-.667-.51l-.567-.009z" />
          </svg>
          Share Invoice via WhatsApp
          <svg
            className="w-4 h-4 opacity-70 group-hover:translate-x-0.5 transition-transform"
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M9 5l7 7-7 7"
            />
          </svg>
        </button>
        <p className="text-center text-xs text-slate-400 mt-3">
          Sharing will open WhatsApp and redirect you to the home page.
        </p>
      </div>
    </main>
  );
}
