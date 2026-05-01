"use client";

import { orderApi } from "@/lib/api/order";
import { toastError } from "@/lib/toast";
import { InvoiceResponse } from "@/types/order";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { pdf, PDFDownloadLink } from "@react-pdf/renderer";
import { InvoicePDF } from "@/components/pages/InvoicePdf";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";

// ── Page Component ─────────────────────────────────────────────────────────────
export default function InvoicePage() {
  const router = useRouter();
  const invoiceRef = useRef<HTMLDivElement>(null);

  const [invoice, setInvoice] = useState<InvoiceResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [fetchError, setFetchError] = useState(false);
  const [pdfBlobUrl, setPdfBlobUrl] = useState<string | null>(null);
  const [pdfGenerating, setPdfGenerating] = useState(true);

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

  // ── Generate PDF blob for preview ──
  useEffect(() => {
    if (!invoice) return;

    let cancelled = false;
    setPdfGenerating(true);

    const generatePdf = async () => {
      try {
        const blob = await pdf(<InvoicePDF invoice={invoice} />).toBlob();
        if (!cancelled) {
          setPdfBlobUrl(URL.createObjectURL(blob));
          setPdfGenerating(false);
        }
      } catch (e) {
        console.error("Failed to generate PDF preview:", e);
        if (!cancelled) {
          setPdfGenerating(false);
        }
      }
    };

    generatePdf();

    return () => {
      cancelled = true;
    };
  }, [invoice]);

  // ── Cleanup blob URL on unmount ──
  useEffect(() => {
    return () => {
      if (pdfBlobUrl) {
        URL.revokeObjectURL(pdfBlobUrl);
      }
    };
  }, [pdfBlobUrl]);

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
      <header className="w-full max-w-4xl flex items-center justify-between mb-6">
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

      {/* ── PDF Preview ── */}
      <div className="w-full max-w-4xl bg-white rounded-2xl shadow-xl shadow-slate-200/70 overflow-hidden border border-slate-100">
        {pdfGenerating ? (
          <div className="flex flex-col items-center justify-center h-96 gap-3">
            <div className="w-10 h-10 rounded-full border-4 border-indigo-200 border-t-indigo-500 animate-spin" />
            <p className="text-sm text-slate-400">Generating preview…</p>
          </div>
        ) : (
          <iframe
            src={pdfBlobUrl ?? undefined}
            className="w-full h-[650px] border-0"
            title="Invoice Preview"
          />
        )}
      </div>

      {/* ── Download PDF Button ── */}
      <div className="w-full max-w-4xl mt-6">
        <PDFDownloadLink
          document={<InvoicePDF invoice={invoice!} />}
          fileName={`invoice-${invoice?.id}.pdf`}
          className="flex justify-center w-full"
        >
          {({ loading }) => (
            <StockFlowButton
              text={loading ? "Generating PDF..." : "Download Invoice PDF"}
              variant="filled"
            />
          )}
        </PDFDownloadLink>
      </div>
    </main>
  );
}
