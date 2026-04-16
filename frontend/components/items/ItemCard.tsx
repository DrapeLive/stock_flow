"use client";

import Image from "next/image";
import { ChevronDown, ChevronUp, Eye, Printer, Info } from "lucide-react";
import { ItemStockEntry, ItemType } from "@/types/item";
import { AssignedItem } from "@/types/agent";
import VariantCard from "./VariantCard";

interface ItemCardProps {
  item: ItemStockEntry | AssignedItem;
  context: "admin" | "agent";
  isExpanded: boolean;
  onToggle: () => void;
  onEdit?: (id: number) => void;
  onPrintAll?: (id: number) => void;
  onPrintQR?: (qr: string) => void;
  onOrder?: (variantId: number) => void;
}

function getItemImage(item: ItemStockEntry | AssignedItem): string | null {
  if ("image" in item) {
    return item.image;
  }
  return item.variants[0]?.image || null;
}

function hasOutOfStockVariants(item: ItemStockEntry | AssignedItem): boolean {
  for (const variant of item.variants) {
    let variantHasStock = false;

    if ("sizes" in variant) {
      variantHasStock = variant.sizes.some(
        (s: { stock: number }) => s.stock > 0,
      );
    } else if ("size_ranges" in variant) {
      variantHasStock = variant.size_ranges.some(
        (sr: { stock: number }) => sr.stock > 0,
      );
    }

    if (!variantHasStock) return true;
  }
  return false;
}

export default function ItemCard({
  item,
  context,
  isExpanded,
  onToggle,
  onEdit,
  onPrintAll,
  onPrintQR,
  onOrder,
}: ItemCardProps) {
  const hasPartialOutOfStock = hasOutOfStockVariants(item);
  const image = getItemImage(item);
  const price = "price" in item ? item.price : null;

  return (
    <div
      className={`rounded-2xl overflow-hidden transition-all ${
        isExpanded
          ? "bg-gray-50 border border-gray-200"
          : "bg-white border border-gray-100"
      }`}
    >
      <div
        className={`flex items-center gap-3 p-4 cursor-pointer transition-colors ${
          isExpanded ? "" : "hover:bg-gray-50/50"
        }`}
        onClick={onToggle}
      >
        <div className="relative w-14 h-14 rounded-xl bg-gray-50 overflow-hidden flex-shrink-0 border border-gray-100">
          {image ? (
            <Image
              src={image}
              alt={item.name}
              fill
              className="object-cover"
              unoptimized
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center">
              <Info size={20} className="text-gray-300" />
            </div>
          )}
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <h6 className="font-bold text-gray-900 text-sm truncate leading-tight">
              {item.name}
            </h6>
            {item.type && (
              <span className="text-[9px] bg-gray-100 text-gray-500 px-1.5 py-0.5 rounded-md uppercase font-bold tracking-tighter border border-gray-200 flex-shrink-0">
                {item.type}
              </span>
            )}
          </div>
          <div className="flex items-center gap-2 mt-1">
            <span className="text-xs text-gray-400">
              {item.variants.length} variant
              {item.variants.length !== 1 ? "s" : ""}
            </span>
            {price && context === "agent" && (
              <>
                <span className="text-gray-200">•</span>
                <span className="text-xs font-bold text-primary">
                  ₹{Number(price).toLocaleString("en-IN")}
                </span>
              </>
            )}
            {hasPartialOutOfStock && context === "admin" && (
              <>
                <span className="text-gray-200">•</span>
                <span className="text-xs text-red-500 font-medium">
                  Some out
                </span>
              </>
            )}
          </div>
        </div>

        <div className="flex items-center gap-1 flex-shrink-0">
          {context === "admin" && (
            <>
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation();
                  onEdit?.(item.id);
                }}
                className="p-2 bg-gray-100 text-gray-500 hover:bg-gray-200 rounded-xl transition-colors"
                title="Edit Item"
              >
                <Eye size={14} />
              </button>
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation();
                  onPrintAll?.(item.id);
                }}
                className="p-2 bg-gray-100 text-gray-500 hover:bg-gray-200 rounded-xl transition-colors"
                title="Print All QR"
              >
                <Printer size={14} />
              </button>
            </>
          )}
          <div
            className={`p-2 rounded-xl transition-colors ${
              isExpanded ? "bg-primary text-white" : "bg-gray-100 text-gray-500"
            }`}
          >
            {isExpanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
          </div>
        </div>
      </div>

      {isExpanded && (
        <div className="px-4 pb-4 pt-2">
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2">
            {item.variants.map((variant, index) => (
              <VariantCard
                key={variant.id}
                variant={variant}
                index={index}
                context={context}
                isCompact={true}
                itemType={item.type as ItemType}
                onPrintQR={context === "admin" ? onPrintQR : undefined}
                onOrder={context === "agent" ? onOrder : undefined}
              />
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
