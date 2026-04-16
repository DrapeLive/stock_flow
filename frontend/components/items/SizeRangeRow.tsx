"use client";

import { SIZE_RANGE_PIECE_COUNT } from "@/types/item";

interface SizeRangeRowProps {
  sizeRange: string;
  stock: number;
  isDisabled?: boolean;
}

export default function SizeRangeRow({
  sizeRange,
  stock,
  isDisabled = false,
}: SizeRangeRowProps) {
  const piecesPerSet = SIZE_RANGE_PIECE_COUNT[sizeRange] || 1;
  const setsAvailable = Math.floor(stock / piecesPerSet);

  return (
    <div
      className={`flex-shrink-0 px-3 py-2 rounded-lg min-w-[80px] ${
        isDisabled ? "bg-gray-100 opacity-50" : "bg-gray-50"
      }`}
    >
      <span
        className={`text-xs font-bold block ${isDisabled ? "text-gray-400" : "text-gray-700"}`}
      >
        {sizeRange}
      </span>
      <span
        className={`text-sm font-black block ${isDisabled ? "text-red-400" : "text-gray-900"}`}
      >
        {setsAvailable} Sets
      </span>
      <span className="text-[10px] text-gray-400 block">
        {piecesPerSet} pcs/set
      </span>
    </div>
  );
}
