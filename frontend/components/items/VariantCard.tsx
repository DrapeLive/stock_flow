"use client";

import { Printer } from "lucide-react";
import { ImagePreview } from "@/components/pages/ImagePreview";
import {
  SIZE_RANGE_TO_SIZES,
  SIZE_RANGE_PIECE_COUNT,
  ItemType,
  UIVariant,
  FrontendSizeRange,
} from "@/types/item";
import SizeRangeRow from "./SizeRangeRow";

interface VariantCardProps {
  variant: UIVariant;
  index: number;
  context: "admin" | "agent";
  isCompact?: boolean;
  onPrintQR?: (qr: string) => void;
  onOrder?: (variantId: number) => void;
  itemType?: ItemType;
}

function getSizeRangesWithStock(
  variant: UIVariant,
  itemType?: ItemType,
): { sizeRange: string; stock: number }[] {
  const sizes = variant.sizes;

  const result: { sizeRange: FrontendSizeRange; stock: number }[] = [];

  // Convert sizes to map for quick lookup
  const sizeMap: Record<string, number> = {};
  for (const s of sizes) {
    sizeMap[s.size] = s.stock;
  }

  for (const [range, groupedSizes] of Object.entries(SIZE_RANGE_TO_SIZES) as [
    FrontendSizeRange,
    string[],
  ][]) {
    const matched = groupedSizes.filter((s) => sizeMap[s] !== undefined);

    // ❌ skip if nothing matches
    if (matched.length === 0) continue;

    // =========================
    // 👕 GENTS LOGIC
    // =========================
    if (itemType === "gents") {
      // ✅ only consider FULL matches
      if (matched.length !== groupedSizes.length) continue;

      const stocks = groupedSizes.map((s) => sizeMap[s]);
      const minStock = Math.min(...stocks);

      result.push({
        sizeRange: range,
        stock: minStock,
      });
    }

    // =========================
    // 👶 KIDS LOGIC
    // =========================
    else {
      // require full match
      if (matched.length !== groupedSizes.length) continue;

      const stocks = groupedSizes.map((s) => sizeMap[s]);
      const minStock = Math.min(...stocks);

      result.push({
        sizeRange: range,
        stock: minStock,
      });
    }
  }

  // =========================
  // 🧠 IMPORTANT PART (GENTS ONLY)
  // =========================
  if (itemType === "gents") {
    // pick ONLY the largest matching group
    return result.length
      ? [
          result.sort(
            (a, b) =>
              SIZE_RANGE_TO_SIZES[b.sizeRange].length -
              SIZE_RANGE_TO_SIZES[a.sizeRange].length,
          )[0],
        ]
      : [];
  }

  return result;
}
function isVariantOutOfStock(variant: UIVariant, itemType?: ItemType): boolean {
  const sizeRanges = getSizeRangesWithStock(variant, itemType);
  return sizeRanges.every((s) => {
    return s.stock === 0;
  });
}

export default function VariantCard({
  variant,
  index,
  context,
  isCompact = false,
  onPrintQR,
  onOrder,
  itemType,
}: VariantCardProps) {
  const isOutOfStock = isVariantOutOfStock(variant, itemType);
  const sizeRanges = getSizeRangesWithStock(variant, itemType);
  const qrCode = "qr_code" in variant ? variant.qr_code : null;

  if (isCompact) {
    return (
      <div
        className={`rounded-lg border p-3 ${
          isOutOfStock
            ? "bg-gray-100 border-gray-200 opacity-60"
            : "bg-white border-gray-100"
        }`}
      >
        <div className="flex items-center gap-2 mb-2">
          <div className="relative w-8 h-8 rounded bg-gray-200 overflow-hidden flex-shrink-0">
            {variant.image ? (
              <ImagePreview src={variant.image} alt={`Variant ${index + 1}`} />
            ) : (
              <div className="w-full h-full" />
            )}
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-xs font-semibold text-gray-700 truncate">
              #{index + 1}
            </p>
            {qrCode && (
              <p className="text-[10px] text-gray-400 truncate">
                {qrCode.slice(0, 10)}...
              </p>
            )}
          </div>
        </div>

        <div className="flex gap-1.5 overflow-x-auto pb-1 scrollbar-none">
          {sizeRanges.map(({ sizeRange, stock }) => (
            <SizeRangeRow
              key={sizeRange}
              sizeRange={sizeRange}
              stock={stock}
              isDisabled={isOutOfStock}
            />
          ))}
        </div>

        <div className="flex items-center justify-end gap-1.5 mt-2">
          {context === "admin" && qrCode && (
            <button
              onClick={() => onPrintQR?.(qrCode)}
              className="p-1.5 bg-gray-100 hover:bg-gray-200 text-gray-600 rounded-lg transition-colors"
            >
              <Printer size={12} />
            </button>
          )}
          {context === "agent" && (
            <button
              onClick={() => onOrder?.(variant.id)}
              disabled={isOutOfStock}
              className={`px-3 py-1 rounded-lg text-xs font-bold transition-colors ${
                isOutOfStock
                  ? "bg-gray-100 text-gray-400 cursor-not-allowed"
                  : "bg-primary text-white hover:bg-primary/90"
              }`}
            >
              Order
            </button>
          )}
        </div>
      </div>
    );
  }

  return (
    <div
      className={`rounded-xl border p-4 ${
        isOutOfStock
          ? "bg-gray-50 border-gray-200 opacity-60"
          : "bg-white border-gray-100"
      }`}
    >
      <div className="flex items-center gap-3 mb-3">
        <div className="relative w-12 h-12 rounded-lg overflow-hidden bg-gray-100 border border-gray-200 flex-shrink-0">
          {variant.image ? (
            <ImagePreview src={variant.image} alt={`Variant ${index + 1}`} />
          ) : (
            <div className="w-full h-full" />
          )}
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold text-gray-700">
            Variant #{index + 1}
          </p>
          {qrCode && (
            <p className="text-xs text-gray-400">QR: {qrCode.slice(0, 8)}...</p>
          )}
        </div>
      </div>

      <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-none">
        {sizeRanges.map(({ sizeRange, stock }) => (
          <SizeRangeRow
            key={sizeRange}
            sizeRange={sizeRange}
            stock={stock}
            isDisabled={isOutOfStock}
          />
        ))}
      </div>

      <div className="flex items-center justify-end gap-2 mt-2">
        {context === "admin" && qrCode && (
          <button
            onClick={() => onPrintQR?.(qrCode)}
            className="flex items-center gap-1.5 px-3 py-2 bg-gray-100 hover:bg-gray-200 text-gray-600 rounded-lg text-xs font-bold transition-colors"
          >
            <Printer size={14} />
            QR
          </button>
        )}
        {context === "agent" && (
          <button
            onClick={() => onOrder?.(variant.id)}
            disabled={isOutOfStock}
            className={`flex items-center gap-1.5 px-4 py-2 rounded-lg text-xs font-bold transition-colors ${
              isOutOfStock
                ? "bg-gray-100 text-gray-400 cursor-not-allowed"
                : "bg-primary text-white hover:bg-primary/90"
            }`}
          >
            Order
          </button>
        )}
      </div>
    </div>
  );
}
