"use client";

import Image from "next/image";
import { Printer } from "lucide-react";
import { ImagePreview } from "@/components/pages/ImagePreview";
import {
  ItemVariantQR,
  SIZE_RANGE_TO_SIZES,
  SIZE_RANGE_PIECE_COUNT,
  SIZES_BY_TYPE,
  ItemType,
} from "@/types/item";
import { AgentItemVariant } from "@/types/agent";
import SizeRangeRow from "./SizeRangeRow";

interface VariantCardProps {
  variant: ItemVariantQR | AgentItemVariant;
  index: number;
  context: "admin" | "agent";
  isCompact?: boolean;
  onPrintQR?: (qr: string) => void;
  onOrder?: (variantId: number) => void;
  itemType?: ItemType;
}

function getSizeRangesWithStock(
  variant: ItemVariantQR | AgentItemVariant,
  itemType?: ItemType,
): { sizeRange: string; stock: number }[] {
  const hasSizeRanges = "size_ranges" in variant;
  const sizes = "sizes" in variant ? (variant as ItemVariantQR).sizes : undefined;

  if (hasSizeRanges) {
    if (itemType === "gents") {
      const sizeRanges = variant.size_ranges.map((sr) => ({
        sizeRange: sr.size_range,
        stock: sr.stock,
      }));
      return getPerfectMatchSizes(sizeRanges, sizes);
    }
    if (itemType === "kids") {
      const sizeRanges = variant.size_ranges.map((sr) => ({
        sizeRange: sr.size_range,
        stock: sr.stock,
      }));
      return getMinStockForKids(sizeRanges, sizes);
    }
    return variant.size_ranges.map((sr) => ({
      sizeRange: sr.size_range,
      stock: sr.stock,
    }));
  }

  if (itemType === "gents") {
    const sizeRanges = getSizeRangesWithStockGrouped(variant, itemType);
    return getPerfectMatchSizes(sizeRanges, sizes);
  }

  if (itemType === "kids") {
    return getSizeRangesWithStockGrouped(variant, itemType);
  }

  return getSizeRangesWithStockGrouped(variant);
}

function getSizeRangesWithStockGrouped(
  variant: ItemVariantQR | AgentItemVariant,
  itemType?: ItemType,
): { sizeRange: string; stock: number }[] {
  const sizes =
    "sizes" in variant ? ((variant as ItemVariantQR).sizes as { size: string; stock: number }[]) : [];
  const sizeGroups: Record<string, number> = {};
  const sizeMinStock: Record<string, number> = {};

  for (const sizeObj of sizes) {
    for (const [range, sizesInRange] of Object.entries(SIZE_RANGE_TO_SIZES)) {
      if (sizesInRange.includes(sizeObj.size)) {
        if (itemType === "kids") {
          const currentMin = sizeMinStock[range];
          if (currentMin === undefined || sizeObj.stock < currentMin) {
            sizeMinStock[range] = sizeObj.stock;
          }
        } else {
          sizeGroups[range] = (sizeGroups[range] || 0) + sizeObj.stock;
        }
      }
    }
  }

  if (itemType === "kids") {
    return Object.entries(sizeMinStock).map(([sizeRange, stock]) => ({
      sizeRange,
      stock,
    }));
  }

  return Object.entries(sizeGroups).map(([sizeRange, stock]) => ({
    sizeRange,
    stock,
  }));
}

function getMinStockForKids(
  sizeRanges: { sizeRange: string; stock: number }[],
  sizes?: { size: string; stock: number }[],
): { sizeRange: string; stock: number }[] {
  if (!sizes || sizes.length === 0) return sizeRanges;

  return sizeRanges.map(({ sizeRange }) => {
    const rangeSizes = SIZE_RANGE_TO_SIZES[sizeRange as keyof typeof SIZE_RANGE_TO_SIZES];
    if (!rangeSizes) return { sizeRange, stock: 0 };

    const availableSizes = sizes.filter((s) => rangeSizes.includes(s.size));
    if (availableSizes.length === 0) return { sizeRange, stock: 0 };

    const minStock = Math.min(...availableSizes.map((s) => s.stock));
    return { sizeRange, stock: minStock };
  });
}

function getPerfectMatchSizes(
  sizeRanges: { sizeRange: string; stock: number }[],
  sizes?: { size: string; stock: number }[],
): { sizeRange: string; stock: number }[] {
  if (!sizes || sizes.length === 0) return sizeRanges;

  const variantSizes = Array.from(new Set(sizes.map((s) => s.size)));
  const variantSizeSet = new Set(variantSizes);

  for (const range of SIZES_BY_TYPE.gents) {
    const rangeSizes = SIZE_RANGE_TO_SIZES[range];
    const rangeSizeSet = new Set(rangeSizes);

    if (
      rangeSizeSet.size === variantSizeSet.size &&
      [...rangeSizeSet].every((s) => variantSizeSet.has(s))
    ) {
      const matched = sizeRanges.find((sr) => sr.sizeRange === range);
      return matched ? [matched] : [];
    }
  }

  return sizeRanges;
}

function isVariantOutOfStock(
  variant: ItemVariantQR | AgentItemVariant,
  itemType?: ItemType,
): boolean {
  const sizeRanges = getSizeRangesWithStock(variant, itemType);
  return sizeRanges.every(({ stock, sizeRange }) => {
    const piecesPerSet = SIZE_RANGE_PIECE_COUNT[sizeRange] || 1;
    return Math.floor(stock / piecesPerSet) === 0;
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
              <ImagePreview
                src={variant.image}
                alt={`Variant ${index + 1}`}
              />
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
            <ImagePreview
              src={variant.image}
              alt={`Variant ${index + 1}`}
            />
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