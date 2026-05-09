"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter, useSearchParams } from "next/navigation";

import { itemApi } from "@/lib/api/item";
import type { ItemQRResponse, ItemStockEntry } from "@/types/item";

import { pdf, PDFDownloadLink } from "@react-pdf/renderer";
import { QRLabelPdf } from "@/components/pages/items/qr/QRLabelPdf";

import QRCode from "qrcode";
import Image from "next/image";
import { ChevronLeft } from "lucide-react";

type QRVariant = {
  id: number;
  qr_code?: string;
  image?: string | null;
  sizes?: {
    size: string;
    stock: number;
  }[];
  total_stock?: number;
};

type ParsedItem = {
  id: number;
  name: string;
  type: string;
  price: string | number;
  image: string | null;
  variants: QRVariant[];
};

export default function QRPrintPage() {
  const searchParams = useSearchParams();

  const itemId = searchParams.get("item");
  const qrId = searchParams.get("qr");

  const router = useRouter();

  const [item, setItem] = useState<ParsedItem | null>(null);

  const [pdfBlobUrl, setPdfBlobUrl] = useState<string | null>(null);

  const [qrImages, setQrImages] = useState<Record<number, string>>({});

  const [loading, setLoading] = useState(true);

  const isMobile =
    typeof window !== "undefined" && /Mobi|Android/i.test(navigator.userAgent);

  useEffect(() => {
    const fetchData = async () => {
      try {
        // ── Full item QR page ──
        if (itemId) {
          const data: ItemStockEntry = await itemApi.getOne(Number(itemId));

          const variants = data.variants.map((v) => ({
            id: v.id,
            qr_code: v.qr_code,
            image: v.image,
            sizes: v.sizes.map((s) => ({
              size: s.size,
              stock: s.stock,
            })),
            total_stock: v.sizes.reduce((sum, s) => sum + s.stock, 0),
          }));

          const parsedItem: ParsedItem = {
            id: data.id,
            name: data.name,
            type: data.type || "gents",
            price: data.price,
            image: variants[0]?.image || null,
            variants,
          };

          await prepareItem(parsedItem);
        }

        // ── Single QR page ──
        else if (qrId) {
          const data: ItemQRResponse = await itemApi.byqr(qrId);

          const matchedVariant =
            data.variants.find((v) => v.qr_code === qrId) || data.variants[0];

          const parsedItem: ParsedItem = {
            id: data.id,
            name: data.name,
            type: "gents",
            price: data.price,
            image: matchedVariant?.image || null,
            variants: [matchedVariant],
          };

          await prepareItem(parsedItem);
        }
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [itemId, qrId]);

  const prepareItem = async (parsedItem: ParsedItem) => {
    setItem(parsedItem);

    const qrMap: Record<number, string> = {};

    for (const variant of parsedItem.variants) {
      qrMap[variant.id] = await QRCode.toDataURL(
        variant.qr_code || String(variant.id),
      );
    }

    setQrImages(qrMap);

    const blob = await pdf(
      <QRLabelPdf item={parsedItem} qrImages={qrMap} />,
    ).toBlob();

    setPdfBlobUrl(URL.createObjectURL(blob));
  };

  if (loading || !item) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        Loading...
      </div>
    );
  }

  return (
    <main className="h-screen flex flex-col">
      {/* ── Header ── */}
      <header className="w-full flex items-center p-4">
        <button
          onClick={() => router.push("/admin/items")}
          className="flex items-center gap-1.5"
        >
          <ChevronLeft className="w-7 h-7" />
          Back
        </button>
      </header>

      {/* ── Preview Area ── */}
      <div className="flex-1 overflow-y-auto p-4">
        {isMobile ? (
          <div className="flex flex-col gap-3 items-center pb-4">
            {item.variants.map((variant, index) => (
              <div
                key={variant.id}
                className="bg-white border shadow-sm flex flex-col items-center justify-center w-full max-w-sm min-h-[90mm] px-4 py-6"
              >
                <p className="text-[11px] font-bold text-center">{item.name}</p>

                <p className="text-[9px] bg-gray-100 px-2 py-1 rounded mt-1">
                  Variant #{index + 1}
                </p>

                <Image
                  src={qrImages[variant.id]}
                  alt="QR Code"
                  width={130}
                  height={130}
                  className="mt-3"
                />

                <p className="text-sm font-extrabold mt-2">
                  Rs. {Number(item.price).toFixed(2)}
                </p>
              </div>
            ))}
          </div>
        ) : (
          <iframe
            src={pdfBlobUrl ?? undefined}
            className="w-full h-full border-0 bg-white"
            title="QR Labels PDF Preview"
          />
        )}
      </div>

      {/* ── Download Bar ── */}
      <div className="sticky bottom-0 p-4 bg-white border-t">
        <PDFDownloadLink
          document={<QRLabelPdf item={item} qrImages={qrImages} />}
          fileName={`${item.name}-${item.id}.pdf`}
          className="w-full flex justify-center"
        >
          {({ loading }) => (
            <button className="w-full max-w-md px-4 py-3 bg-primary text-white rounded-2xl font-medium">
              {loading ? "Generating..." : "Download PDF"}
            </button>
          )}
        </PDFDownloadLink>
      </div>
    </main>
  );
}
