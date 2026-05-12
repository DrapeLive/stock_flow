"use client";
import { itemApi } from "@/lib/api/item";
import { toastError, toastSuccess } from "@/lib/toast";
import { Scanner } from "@yudiel/react-qr-scanner";
import { QrCode, Sparkles } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState } from "react";

interface ScannerPageProps {
  id: string;
  basePath?: string;
}

const ScannerPage: React.FC<ScannerPageProps> = ({
  id,
  basePath = "/agent/order/new",
}) => {
  const [validating, setValidating] = useState(false);
  const router = useRouter();

  return (
    <div className="w-full max-w-sm flex flex-col items-center">
      <div className="relative w-full aspect-square max-w-[280px]">
        {/* Corner Brackets */}
        <div className="absolute -top-2 -left-2 w-8 h-8 border-t-4 border-l-4 border-primary rounded-tl-2xl z-20" />
        <div className="absolute -top-2 -right-2 w-8 h-8 border-t-4 border-r-4 border-primary rounded-tr-2xl z-20" />
        <div className="absolute -bottom-2 -left-2 w-8 h-8 border-b-4 border-l-4 border-primary rounded-bl-2xl z-20" />
        <div className="absolute -bottom-2 -right-2 w-8 h-8 border-b-4 border-r-4 border-primary rounded-br-2xl z-20" />

        {/* Scanner Container */}
        <div className="relative w-full h-full rounded-[32px] overflow-hidden bg-black shadow-2xl ring-8 ring-white/50">
          <Scanner
            constraints={{
              facingMode: "environment",
              width: { ideal: 1280 },
              height: { ideal: 720 },
            }}
            onScan={async (data) => {
              if (data[0]?.rawValue && !validating) {
                const qrValue = data[0].rawValue;
                setValidating(true);
                try {
                  const result = await itemApi.checkOutOfStock(qrValue);
                  console.log(result.out_of_stock);
                  console.log(result.group_stock);
                  if (result.out_of_stock) {
                    toastError(
                      "Out of stock",
                      "All sizes for this item are unavailable.",
                    );
                    return;
                  }
                  const item = await itemApi.byqr(qrValue);
                  toastSuccess(
                    "QR code scanned successfully",
                    `Scanned Item: ${item.name}`,
                  );
                  router.push(`${basePath}/${id}/${qrValue}`);
                } catch (e) {
                  toastError("Invalid QR code", e);
                } finally {
                  setValidating(false);
                }
              }
            }}
            onError={(err) => console.error(err)}
            classNames={{
              container: "w-full h-full",
              video: "w-full h-full object-cover",
            }}
          />
        </div>
      </div>

      <div className="mt-12 text-center">
        <div className="inline-flex items-center gap-2 bg-primary/10 text-primary px-4 py-2 rounded-full border border-primary/20 mb-4">
          <QrCode size={16} />
          <span className="text-xs font-black uppercase tracking-widest">
            {validating ? "Checking..." : "Awaiting Scan"}
          </span>
        </div>
        <h2 className="text-lg font-bold text-gray-800">Align QR Code</h2>
        <p className="text-sm text-gray-400 mt-2 max-w-[200px] mx-auto leading-relaxed font-medium">
          Position the item&apos;s QR code within the frame to add it to the
          order
        </p>
      </div>

      <div className="mt-8 flex items-center justify-center gap-2 text-primary/40 animate-pulse">
        <Sparkles size={16} />
        <span className="text-[10px] font-bold uppercase tracking-widest">
          Auto-detecting
        </span>
      </div>
    </div>
  );
};

export default ScannerPage;
