"use client";

import { Order, OrderStatus } from "@/types/order";
import { User } from "lucide-react";
import { useRouter } from "next/navigation";

interface OrderCardProps {
  order: Order;
  onClick?: () => void;
}

function getColorFromId(id: number) {
  if (!id) return "hsl(0, 0%, 85%)"; // fallback

  const hue = (id * 137.508) % 360;
  return `hsl(${hue}, 65%, 85%)`; // lighter for background
}

const statusConfig: Record<
  OrderStatus,
  { bg: string; text: string; label: string }
> = {
  DRAFT: {
    bg: "bg-gray-100",
    text: "text-gray-600",
    label: "Draft",
  },
  PENDING: {
    bg: "bg-amber-100",
    text: "text-amber-700",
    label: "Pending",
  },
  EDITING: {
    bg: "bg-purple-100",
    text: "text-purple-700",
    label: "Editing",
  },
  PACKED: {
    bg: "bg-blue-100",
    text: "text-blue-700",
    label: "Packed",
  },
  DISPATCHED: {
    bg: "bg-green-100",
    text: "text-green-700",
    label: "Dispatched",
  },
};

export default function OrderCard({ order, onClick }: OrderCardProps) {
  const router = useRouter();
  const status = statusConfig[order.status || "PENDING"];

  const totalSets = order.total_sets || 0;
  const totalPieces = order.total_pieces || 0;
  const piecesPerSet = totalSets > 0 ? totalPieces / totalSets : 0;

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr);
    return date.toLocaleDateString("en-IN", {
      day: "2-digit",
      month: "short",
    });
  };

  const handleClick = () => {
    if (onClick) {
      onClick();
    } else {
      router.push(`/admin/order/status/${order.id}`);
    }
  };

  return (
    <div
      onClick={handleClick}
      className="bg-white border border-gray-100 p-4 rounded-2xl hover:border-primary/30 hover:shadow-md transition-all cursor-pointer active:scale-[0.99]"
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-3 min-w-0">
          <div
            className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0"
            style={{
              backgroundColor: getColorFromId(order.customer_details?.id),
            }}
          >
            <User size={18} color="white" className="text-primary" />
          </div>
          <div className="min-w-0">
            <h6 className="font-bold text-gray-900 text-sm truncate leading-tight">
              {order.customer_details?.name || "Unknown Customer"}
            </h6>
            <p className="text-xs text-gray-400 mt-0.5">
              {order.items.map((item) => item.item_name).join(", ")}
            </p>
            <p className="text-xs text-gray-400 mt-0.5">
              {formatDate(order.created_at)}
            </p>
          </div>
        </div>

        <span
          className={`px-2 py-1 rounded-full text-[10px] font-bold uppercase tracking-wide flex-shrink-0 ${status.bg} ${status.text}`}
        >
          {status.label}
        </span>
      </div>

      <div className="flex items-center justify-between mt-4 pt-3 border-t border-gray-50">
        <div className="flex items-center gap-1.5">
          <span className="text-base font-black text-gray-900">
            {totalSets}
          </span>
          <span className="text-xs text-gray-400">Sets</span>
          <span className="text-gray-300 mx-1">•</span>
          <span className="text-sm font-bold text-gray-600">{totalPieces}</span>
          <span className="text-xs text-gray-400">pcs</span>
        </div>

        <div className="text-right">
          <span className="text-sm font-black text-primary">
            ₹
            {order.items
              ?.reduce(
                (sum, item) =>
                  sum +
                  (Number(item.item_price) || 0) *
                    item.quantity *
                    (item.piece_count || 1),
                0,
              )
              .toLocaleString("en-IN")}
          </span>
        </div>
      </div>
    </div>
  );
}
