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
      <div className={isMobile ? "w-full" : "w-full max-w-4xl"}>
        {isMobile ? (
          <div className="flex flex-col w-full gap-4">
            <div ref={invoiceRef} className="bg-white w-full">
              {/* ── Brand Header ── */}
              <div className="flex items-center justify-between mb-4">
                <div className="w-12 h-12 rounded overflow-hidden flex items-center justify-center bg-gray-100">
                  {invoice.brand?.logo_url ? (
                    <img
                      src={invoice.brand.logo_url}
                      alt="Brand Logo"
                      className="w-12 h-12 object-cover rounded"
                    />
                  ) : (
                    <span className="text-[#0f1f3d] text-lg font-bold">
                      {(
                        invoice.brand?.name ??
                        invoice.items[0]?.item_type ??
                        "BR"
                      )
                        .slice(0, 2)
                        .toUpperCase()}
                    </span>
                  )}
                </div>
                <div className="text-right">
                  <p className="text-[#0f1f3d] font-bold text-base">
                    {invoice.brand?.name ?? invoice.items[0]?.item_type}
                  </p>
                  {invoice.brand?.address_line1 && (
                    <p className="text-xs text-gray-600">
                      {invoice.brand.address_line1}
                    </p>
                  )}
                  {invoice.brand?.address_line2 && (
                    <p className="text-xs text-gray-600">
                      {invoice.brand.address_line2}
                    </p>
                  )}
                  {invoice.brand?.phone && (
                    <p className="text-xs text-gray-600">
                      {invoice.brand.phone}
                    </p>
                  )}
                  {invoice.brand?.email && (
                    <p className="text-xs text-gray-600">
                      {invoice.brand.email}
                    </p>
                  )}
                  {invoice.brand?.gst && (
                    <p className="text-xs text-gray-600">
                      GST : {invoice.brand.gst}
                    </p>
                  )}
                </div>
              </div>

              <div className="border-b-2 border-[#0f1f3d] mb-4" />

              {/* ── ORDER FORM Title ── */}
              <div className="flex justify-between items-start mb-4">
                <p className="text-[#0f1f3d] text-xl font-bold tracking-wider">
                  ORDER FORM
                </p>
                <div className="text-right text-xs text-gray-700">
                  <p>
                    Order Form{" "}
                    <span className="font-bold">#{String(invoice.id)}</span>
                  </p>
                  <p>
                    Date :{" "}
                    <span className="font-bold">
                      {formatDate(invoice.created_at)}
                    </span>
                  </p>
                  <p>
                    Time :{" "}
                    <span className="font-bold">
                      {formatTime(invoice.created_at)}
                    </span>
                  </p>
                </div>
              </div>

              <div className="border-b border-gray-300 mb-4" />

              {/* ── Customer & Agent ── */}
              <div className="flex mb-4">
                <div className="flex-1 pr-4 border-r border-gray-300">
                  <span className="bg-[#0f1f3d] text-white text-[10px] font-bold uppercase px-1.5 py-0.5">
                    Customer:
                  </span>
                  <p className="text-[#0f1f3d] font-bold text-sm mt-1">
                    {invoice.customer.name}
                  </p>
                  {invoice.customer.address && (
                    <p className="text-xs text-gray-600">
                      {invoice.customer.address}
                    </p>
                  )}
                  {invoice.customer.contact && (
                    <p className="text-xs text-gray-600">
                      {invoice.customer.contact}
                    </p>
                  )}
                </div>
                <div className="flex-1 pl-4">
                  <span className="bg-[#0f1f3d] text-white text-[10px] font-bold uppercase px-1.5 py-0.5">
                    Agent:
                  </span>
                  <p className="text-[#0f1f3d] font-bold text-sm mt-1">
                    {invoice.agent.username}
                  </p>
                  {invoice.agent.contact && (
                    <p className="text-xs text-gray-600">
                      {invoice.agent.contact}
                    </p>
                  )}
                </div>
              </div>

              {/* ── Items Table ── */}
              <div className="border border-[#0f1f3d] mb-4 overflow-x-auto">
                <div className="flex bg-[#0f1f3d] py-2 px-1">
                  <p className="w-[30%] text-center text-white text-[10px] font-bold">
                    Item
                  </p>
                  <p className="w-[22%] text-center text-white text-[10px] font-bold">
                    Size
                  </p>
                  <p className="w-[18%] text-center text-white text-[10px] font-bold">
                    Price
                  </p>
                  <p className="w-[12%] text-center text-white text-[10px] font-bold">
                    Qty
                  </p>
                  <p className="w-[18%] text-center text-white text-[10px] font-bold">
                    Amount
                  </p>
                </div>

                {invoice.items.map((item, idx) => {
                  const pieceCount = item.piece_count || 1;
                  const totalPieces = item.quantity * pieceCount;
                  const itemPrice = parseFloat(String(item.item_price)) || 0;
                  const amount = itemPrice * item.quantity * pieceCount;

                  return (
                    <div
                      key={item.id}
                      className={`flex border-b border-dashed border-gray-300 py-2 px-1 items-center ${
                        idx % 2 === 1 ? "bg-gray-50" : ""
                      }`}
                    >
                      <div className="w-[30%] text-center">
                        <p className="text-[10px] text-gray-800">
                          {item.item_name}
                        </p>
                      </div>
                      <p className="w-[22%] text-center text-[10px] text-gray-800">
                        {item.size_group}
                      </p>
                      <p className="w-[18%] text-center text-[10px] text-gray-800">
                        Rs. {itemPrice.toFixed(2)}/pc
                      </p>
                      <div className="w-[12%] text-center">
                        <p className="text-[10px] text-gray-800">
                          {item.quantity}
                        </p>
                        {pieceCount > 1 && (
                          <p className="text-[9px] text-gray-500">
                            ×{pieceCount}={totalPieces}pc
                          </p>
                        )}
                      </div>
                      <p className="w-[18%] text-center text-[10px] text-gray-800">
                        Rs. {amount.toLocaleString("en-IN")}
                      </p>
                    </div>
                  );
                })}
              </div>

              {/* ── Total ── */}
              <div className="flex justify-end mt-4">
                <span className="bg-[#0f1f3d] text-white text-sm font-bold px-4 py-2">
                  TOTAL:
                </span>
                <div className="border border-[#0f1f3d] px-6 py-2">
                  <p className="text-[#0f1f3d] font-bold">
                    Rs. {invoice.total_price.toLocaleString("en-IN")}
                  </p>
                </div>
              </div>

              {/* ── Footer ── */}
              <div className="flex justify-center items-center mt-8">
                <div className="flex-1 border-b border-gray-400 mb-1" />
                <p className="text-sm text-gray-600 italic px-4">
                  Thank you for your business!
                </p>
                <div className="flex-1 border-b border-gray-400 mb-1" />
              </div>
            </div>

            {/* Open PDF */}
            {pdfBlobUrl && (
              <div className="flex justify-center w-full">
                <StockFlowButton
                  text="Open PDF Preview"
                  variant="outline"
                  onClick={() => {
                    if (pdfBlobUrl) {
                      window.open(pdfBlobUrl, "_blank");
                    }
                  }}
                />
              </div>
            )}
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
