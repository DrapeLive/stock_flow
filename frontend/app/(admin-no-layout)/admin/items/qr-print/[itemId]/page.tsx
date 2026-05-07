"use client";

import { useEffect, useRef, useState } from "react";
import { useParams } from "next/navigation";
import QRCode from "react-qr-code";
import { itemApi } from "@/lib/api/item";
import { ItemStockEntry } from "@/types/item";

const QRPrintPage: React.FC = () => {
  const { itemId } = useParams<{ itemId: string }>();
  const [item, setItem] = useState<ItemStockEntry | null>(null);
  const [loading, setLoading] = useState(true);
  const hasPrinted = useRef(false);

  useEffect(() => {
    if (!itemId) return;
    itemApi
      .getOne(Number(itemId))
      .then((data) => {
        const variants = data.variants.map((v) => ({
          id: v.id,
          qr_code: v.qr_code,
          image: v.image,
          sizes: v.sizes.map((s) => ({ size: s.size, stock: s.stock })),
          total_stock: v.sizes.reduce((sum, s) => sum + s.stock, 0),
        }));
        setItem({
          id: data.id,
          name: data.name,
          type: data.type || "gents",
          price: data.price,
          image: variants[0]?.image || null,
          variants,
        });
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [itemId]);

  useEffect(() => {
    if (!loading && item && !hasPrinted.current) {
      hasPrinted.current = true;
      setTimeout(() => {
        document.title = `${item.name}-${item.id}`.replace(/\s+/g, "-");
        window.print();
        window.onafterprint = () => window.close();
      }, 500);
    }
  }, [loading, item]);

  if (loading || !item) return null;

  return (
    <>
      <style>{`
        @page {
          size: 58mm 90mm;
          margin: 0;
        }
        * { box-sizing: border-box; }
        body { margin: 0; background: white; }
        @media print {
          html, body { width: 58mm; height: 90mm; }
          .qr-page { page-break-after: always; }
          .qr-page:last-child { page-break-after: auto; }
        }
      `}</style>

      {item.variants.map((variant) => (
        <div
          key={variant.id}
          className="qr-page"
          style={{
            width: "58mm",
            height: "90mm",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            gap: "6px",
            padding: "6mm 4mm",
            background: "white",
            fontFamily: "system-ui, sans-serif",
            margin: "0 auto",
          }}
        >
          <p
            style={{
              fontSize: "11px",
              fontWeight: 700,
              textAlign: "center",
              margin: 0,
              lineHeight: 1.2,
              letterSpacing: "-0.01em",
            }}
          >
            {item.name}
          </p>

          <p
            style={{
              fontSize: "9px",
              fontWeight: 600,
              color: "#555",
              textAlign: "center",
              margin: 0,
              background: "#f0f0f0",
              borderRadius: "4px",
              padding: "2px 8px",
              letterSpacing: "0.02em",
            }}
          >
            Variant #{item.variants.indexOf(variant) + 1}
          </p>

          <div style={{ padding: "4px", background: "white" }}>
            <QRCode value={variant.qr_code || String(variant.id)} size={130} />
          </div>

          <p
            style={{
              fontSize: "14px",
              fontWeight: 800,
              margin: 0,
              letterSpacing: "-0.02em",
            }}
          >
            ₹{parseFloat(item.price).toFixed(2)}
          </p>
        </div>
      ))}
    </>
  );
};

export default QRPrintPage;
