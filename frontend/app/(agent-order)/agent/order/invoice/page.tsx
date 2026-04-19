"use client";

import { orderApi } from "@/lib/api/order";
import { toastError } from "@/lib/toast";
import { InvoiceResponse } from "@/types/order";
import { useRouter } from "next/navigation";
import { useRef, useEffect, useState } from "react";
import { PDFDownloadLink } from "@react-pdf/renderer";
import { InvoicePDF } from "@/components/pages/InvoicePdf";
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

// ── Page Component ─────────────────────────────────────────────────────────────
export default function InvoicePage() {
  const router = useRouter();
  const invoiceRef = useRef<HTMLDivElement>(null);

  const [invoice, setInvoice] = useState<InvoiceResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [fetchError, setFetchError] = useState(false);

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
          setFetchError(true);
        }
      } catch (e) {
        console.error("Error fetching order details:", e);
        toastError("Failed to load invoice", e);
        setFetchError(true);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

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
  if (!invoice) {
    return (
      <main className="min-h-screen bg-slate-50 flex items-center justify-center px-4">
        <div className="text-center">
          <p className="text-slate-500 mb-4">Failed to load invoice.</p>
          <button
            onClick={() => {
              localStorage.removeItem("orderKey");
              router.push("/agent");
            }}
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
      {/* ── Header ── */}
      <header className="w-full max-w-2xl flex items-center justify-between mb-6">
        <button
          onClick={() => router.push("/agent")}
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
        className="w-full max-w-2xl mx-4 sm:mx-0 bg-white rounded-2xl shadow-xl shadow-slate-200/70 overflow-hidden border border-slate-100"
      >
        {/* Top accent bar */}
        <div className="h-1.5 w-full bg-primary" />

        {/* ── Invoice Header ── */}
        <div className="px-4 sm:px-8 pt-6 sm:pt-8 pb-5 flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4 border-b border-slate-100">
          <div>
            <p className="text-xs font-semibold tracking-widest text-indigo-500 uppercase mb-1">
              Invoice
            </p>
            <h1 className="font-display text-2xl sm:text-4xl text-slate-800">
              #{invoice.id.toString().padStart(4, "0")}
            </h1>
            <p className="text-xs sm:text-sm text-slate-400 mt-1">
              {formatDate(invoice.created_at)}&nbsp;·&nbsp;
              {formatTime(invoice.created_at)}
            </p>
          </div>

          <div className="flex flex-col items-start sm:items-end gap-2">
            <div className="text-right">
              <p className="text-xs text-slate-400">Agent</p>
              <p className="text-sm font-medium text-slate-700">
                @{invoice.agent.username}
              </p>
            </div>
          </div>
        </div>

        {/* ── Bill To ── */}
        <div className="px-4 sm:px-8 py-5 bg-slate-50/60 border-b border-slate-100">
          <p className="text-xs font-semibold text-slate-400 uppercase tracking-widest mb-1">
            Bill To
          </p>
          <p className="text-base sm:text-lg font-semibold text-slate-800">
            {invoice.customer.name}
          </p>
          <p className="text-xs text-slate-400">
            Customer ID: #{invoice.customer.id}
          </p>
        </div>

        {/* ── Items Table ── */}
        <div className="px-4 sm:px-8 py-6">
          {/* Desktop Table Header */}
          <div className="hidden sm:grid grid-cols-12 bg-slate-800 text-white text-xs font-semibold uppercase tracking-wider px-4 py-3">
            <span className="col-span-5">Item</span>
            <span className="col-span-2 text-center">Size</span>
            <span className="col-span-2 text-center">Sets</span>
            <span className="col-span-3 text-right">Amount</span>
          </div>

          {/* Items */}
          {invoice.items.map((oi, idx) => {
            const pieceCount = oi.piece_count || 1;
            const totalPieces = oi.quantity * pieceCount;
            const itemPrice = oi.item_price || 0;
            const amount = itemPrice * oi.quantity * pieceCount;

            return (
              <div
                key={oi.id}
                className={`px-4 sm:px-4 py-3.5 text-sm border-t border-slate-100 ${
                  idx % 2 === 0 ? "bg-white" : "bg-slate-50"
                }`}
              >
                {/* Mobile Layout */}
                <div className="sm:hidden flex flex-col gap-2">
                  <div className="flex justify-between items-start">
                    <p className="font-medium text-slate-800 text-base">
                      {oi.item_name}
                    </p>
                    <span className="font-semibold text-slate-800 text-base">
                      Rs. {amount.toLocaleString("en-IN")}
                    </span>
                  </div>
                  <div className="flex justify-between items-center text-xs text-slate-500">
                    <span className="bg-slate-100 rounded px-1.5 py-0.5 font-mono">
                      {oi.size_group}
                    </span>
                    <span>
                      {oi.quantity} Set{oi.quantity !== 1 ? "s" : ""} × {pieceCount} pcs = {totalPieces}
                    </span>
                  </div>
                </div>

                {/* Desktop Layout */}
                <div className="hidden sm:grid grid-cols-12 items-center">
                  <div className="col-span-5">
                    <p className="font-medium text-slate-800 text-sm">
                      {oi.item_name}
                    </p>
                    <p className="text-xs text-slate-400 mt-0.5">
                      Rs. {itemPrice.toLocaleString("en-IN")} / pc
                    </p>
                  </div>
                  <span className="col-span-2 text-center text-slate-500 text-xs font-mono bg-slate-100 rounded px-1.5 py-0.5 mx-auto">
                    {oi.size_group}
                  </span>
                  <div className="col-span-2 text-center font-semibold text-slate-700">
                    <div>
                      {oi.quantity} Set{oi.quantity !== 1 ? "s" : ""}
                    </div>
                    <div className="text-[10px] text-slate-400 font-normal">
                      × {pieceCount} pcs = {totalPieces}
                    </div>
                  </div>

                  <span className="col-span-3 text-right font-semibold text-slate-800">
                    Rs. {amount.toLocaleString("en-IN")}
                  </span>
                </div>
              </div>
            );
          })}
        </div>

        {/* ── Totals ── */}
        <div className="px-4 sm:px-8 pb-6 sm:pb-8">
          <div className="ml-auto w-full sm:w-72 rounded-xl bg-slate-50 border border-slate-100 overflow-hidden">
            <div className="flex justify-between px-4 sm:px-5 py-3 text-sm text-slate-500 border-b border-slate-100">
              <span>Subtotal</span>
              <span className="font-medium text-slate-700">
                Rs. {invoice.total_price.toLocaleString("en-IN")}
              </span>
            </div>
            <div className="flex justify-between px-4 sm:px-5 py-3 text-sm text-slate-500 border-b border-slate-100">
              <span>Tax</span>
              <span className="font-medium text-slate-700">—</span>
            </div>
            <div className="flex justify-between px-4 sm:px-5 py-4 bg-slate-800 text-white">
              <span className="font-semibold text-sm tracking-wide">Total</span>
              <span className="font-display text-lg sm:text-xl">
                Rs. {invoice.total_price.toLocaleString("en-IN")}
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

      {/* ── Download PDF Button ── */}
      <div className="w-full max-w-2xl mt-6">
        <PDFDownloadLink
          document={<InvoicePDF invoice={invoice} />}
          fileName={`invoice-${invoice.id}.pdf`}
          className="w-full"
        >
          {({ loading }) => (
            <button className="w-full flex items-center justify-center gap-3 bg-primary hover:bg-primary/90 active:scale-[0.98] text-white font-semibold text-base py-4 rounded-2xl shadow-lg transition-all duration-200">
              {loading ? "Generating PDF..." : "Download Invoice PDF"}
            </button>
          )}
        </PDFDownloadLink>
      </div>
    </main>
  );
}
