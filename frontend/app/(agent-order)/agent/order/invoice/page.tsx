"use client";

import { orderApi } from "@/lib/api/order";
import { toastError } from "@/lib/toast";
import { InvoiceResponse } from "@/types/order";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { pdf, PDFDownloadLink } from "@react-pdf/renderer";
import { InvoicePDF } from "@/components/pages/InvoicePdf";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { useBackButton } from "@/util/useBackButton";
import { mediaUrl } from "@/lib/media";
import OrderForm from "@/components/pages/order-form/OrderFormView";
import { Download, Printer, Share2 } from "lucide-react";
import { PageLoading } from "@/components/ui/Loading";

const formatDate = (iso: string) =>
  new Date(iso).toLocaleDateString("en-IN", {
    day: "numeric",
    month: "numeric",
    year: "numeric",
  });
const formatTime = (iso: string) =>
  new Date(iso).toLocaleTimeString("en-IN", {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: true,
  });

// ── Page Component ─────────────────────────────────────────────────────────────
export default function InvoicePage() {
  const router = useRouter();
  const invoiceRef = useRef<HTMLDivElement>(null);

  const [invoice, setInvoice] = useState<InvoiceResponse | null>(null);
  const [printing, setPrinting] = useState<boolean>(false);
  const [sharing, setSharing] = useState<boolean>(false);
  const [loading, setLoading] = useState(true);
  const [, setFetchError] = useState(false);
  const [pdfBlobUrl, setPdfBlobUrl] = useState<string | null>(null);
  const [pdfGenerating, setPdfGenerating] = useState(true);

  useBackButton({
    onBack: () => {
      router.push("/agent");
    },
  });

  const isMobile =
    typeof window !== "undefined" && /Mobi|Android/i.test(navigator.userAgent);

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

  const handlePrint = async () => {
    if (!pdfBlobUrl) return;
    setPrinting(true);
    try {
      if (isMobile) {
        // Mobile — open in new tab, user prints from browser menu
        window.open(pdfBlobUrl, "_blank");
        setTimeout(() => URL.revokeObjectURL(pdfBlobUrl), 60000);
      } else {
        // Desktop — silent print via hidden iframe
        const iframe = document.createElement("iframe");
        iframe.style.display = "none";
        iframe.src = pdfBlobUrl;
        document.body.appendChild(iframe);
        iframe.onload = () => {
          iframe.contentWindow?.focus();
          iframe.contentWindow?.print();
          setTimeout(() => {
            document.body.removeChild(iframe);
            URL.revokeObjectURL(pdfBlobUrl);
          }, 3000);
        };
      }
    } finally {
      setPrinting(false);
    }
  };

  const handleShare = async () => {
    if (!pdfBlobUrl) return;
    setSharing(true);
    try {
      const file = new File([pdfBlobUrl], `order-form.pdf`, {
        type: "application/pdf",
      });

      if (navigator.canShare?.({ files: [file] })) {
        await navigator.share({
          title: "Order Form",
          text: `Order Form`,
          files: [file],
        });
      } else {
        // Fallback — just download if share not supported
        handleDownload();
      }
    } catch (e) {
      if ((e as Error).name !== "AbortError") console.error(e);
    } finally {
      setSharing(false);
    }
  };

  const handleDownload = () => {
    if (!pdfBlobUrl) return;
    const a = document.createElement("a");
    a.href = pdfBlobUrl;
    a.download = `orderform.pdf`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(pdfBlobUrl), 1000);
  };

  // ── Loading state ──
  if (loading) {
    return <PageLoading text="Loading Order Form..." />;
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
    <main className="min-h-screen font-sans flex flex-col items-center py-10 px-4">
      {/* ── Header ── */}
      <header className="w-full flex items-center justify-between mb-6">
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
      <div className="flex flex-1 w-full overflow-y-auto">
        {isMobile ? (
          <div className="flex flex-col w-full gap-4">
            <OrderForm
              id={invoice.id}
              customer={invoice.customer}
              agent={invoice.agent}
              brand={invoice.brand}
              created_at={invoice.created_at}
              items={invoice.items}
              total_price={invoice.total_price}
              invoiceRef={invoiceRef}
              status={invoice.status}
            />
          </div>
        ) : pdfGenerating ? (
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

      <div className="sticky bottom-0 p-4 border-t">
        <div className="flex gap-3 max-w-md mx-auto">
          {/* Print — hidden on mobile since it opens a new tab */}

          <button
            onClick={handlePrint}
            disabled={printing || !pdfBlobUrl}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-3 border border-gray-200 text-gray-700 rounded-2xl font-medium hover:bg-gray-50 disabled:opacity-50 transition-colors"
          >
            <Printer size={18} />
            {printing ? "Opening..." : "Print"}
          </button>

          {isMobile && (
            <button
              onClick={handleShare}
              disabled={sharing || !pdfBlobUrl}
              className="flex-1 flex items-center justify-center gap-2 px-4 py-3 border border-gray-200 text-gray-700 rounded-2xl font-medium hover:bg-gray-50 disabled:opacity-50 transition-colors"
            >
              <Share2 size={18} />
              {sharing ? "Sharing..." : "Share"}
            </button>
          )}

          {/* Download */}
          <button
            onClick={handleDownload}
            disabled={!pdfBlobUrl}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-primary text-white rounded-2xl font-medium disabled:opacity-50 transition-colors"
          >
            <Download size={18} />
            Download
          </button>
        </div>
      </div>
    </main>
  );
}
