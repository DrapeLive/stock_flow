"use client";

import { Trash2, CheckCircle2, Circle, Pencil } from "lucide-react";
import { ImagePreview } from "@/components/pages/ImagePreview";
import { OrderItem } from "@/types/order";
import { Spinner } from "../ui/spinner";

interface OrderItemRowProps {
  item: OrderItem;
  onDelete?: (itemId: number) => void;
  onEdit?: (item: OrderItem) => void;
  onTogglePacked?: (itemId: number, packed: boolean) => void;
  showDelete?: boolean;
  showEdit?: boolean;
  showPackedToggle?: boolean;
  isPacked?: boolean;
  isOutOfStock?: boolean;
  isLoading?: boolean;
}

export default function OrderItemRow({
  item,
  onDelete,
  onEdit,
  onTogglePacked,
  showDelete = false,
  showEdit = false,
  showPackedToggle = false,
  isPacked = false,
  isOutOfStock = false,
  isLoading = false,
}: OrderItemRowProps) {
  const pieceCount = item.piece_count || 1;
  const quantity = item.quantity;
  const totalPieces = quantity * pieceCount;

  return (
    <div
      className={`flex items-center gap-3  border-b border-gray-50 py-4 px-1 ${
        isPacked ? "bg-green-50" : isOutOfStock ? "bg-red-50" : "bg-white"
      }`}
    >
      <div>
        {showEdit && onEdit && (
          <button
            onClick={() => onEdit(item)}
            className="flex items-center justify-center p-2 flex-shrink-0"
          >
            <Pencil className="text-primary w-4 h-4" />
          </button>
        )}
        {showDelete && onDelete && (
          <button
            onClick={() => onDelete(item.id)}
            className="flex items-center justify-center p-2 flex-shrink-0 hover:cursor-pointer"
          >
            <Trash2 className="text-red-500 w-4 h-4" />
          </button>
        )}
      </div>

      {showPackedToggle && onTogglePacked && (
        <button
          onClick={() => !isLoading && onTogglePacked(item.id, !isPacked)}
          className="flex items-center justify-center p-2 mr-1 flex-shrink-0"
        >
          {isLoading ? (
            <Spinner className="w-6 h-6" />
          ) : isPacked ? (
            <CheckCircle2 className="text-green-600 w-6 h-6" />
          ) : (
            <Circle className="text-gray-300 w-6 h-6 hover:text-primary/50 transition-colors" />
          )}
        </button>
      )}

      <div className="relative w-12 h-12 rounded-lg overflow-hidden flex-shrink-0 border border-gray-100 bg-gray-50">
        {item.variant_image ? (
          <ImagePreview
            src={item.variant_image}
            alt={item.item_name || "Item"}
          />
        ) : (
          <div className="w-full h-full bg-gray-100" />
        )}
      </div>

      <div className="flex-1 min-w-0">
        <h6
          className={`font-semibold text-sm truncate ${
            isPacked
              ? "text-green-700"
              : isOutOfStock
                ? "text-red-700"
                : "text-gray-900"
          }`}
        >
          {item.item_name || "Unknown Item"}
        </h6>
        <p className="text-[10px] text-gray-400 mt-0.5">
          Size: {item.size_group || "N/A"}
        </p>
        <p
          className={`text-xs font-medium mt-1 ${
            isPacked
              ? "text-green-600"
              : isOutOfStock
                ? "text-red-600"
                : "text-gray-600"
          }`}
        >
          {quantity} Set{quantity !== 1 ? "s" : ""} × {pieceCount} pcs ={" "}
          <span
            className={`font-bold ${isOutOfStock ? "text-red-700" : "text-gray-900"}`}
          >
            {totalPieces}
          </span>{" "}
          pcs
        </p>
      </div>

      <div className="text-right flex-shrink-0">
        <span
          className={`text-base font-black ${isOutOfStock ? "text-red-700" : "text-gray-900"}`}
        >
          ₹
          {(
            (Number(item.item_price) || 0) *
            quantity *
            pieceCount
          ).toLocaleString("en-IN")}
        </span>
      </div>
    </div>
  );
}
