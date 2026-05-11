"use client";

import { ChevronDown } from "lucide-react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { getPiecesForGroup } from "../utils";

interface SizeGroupSelectorProps {
  sizeGroups: string[];
  selectedSizeGroup: string | null;
  availableStock: number;
  onSelect: (sizeGroup: string) => void;
}

export default function SizeGroupSelector({
  sizeGroups,
  selectedSizeGroup,
  availableStock,
  onSelect,
}: SizeGroupSelectorProps) {
  const pieceCount = getPiecesForGroup(selectedSizeGroup);

  return (
    <div className="mb-8">
      <div className="flex items-center justify-between mb-3">
        <h3 className="font-bold text-gray-900">Size Group</h3>

        {selectedSizeGroup && (
          <span className="text-[11px] font-bold text-gray-500 uppercase tracking-wider bg-gray-100 px-3 py-1 rounded-full">
            {pieceCount} pcs / set
          </span>
        )}
      </div>

      {sizeGroups.length > 0 ? (
        <div className="relative">
          <Select value={selectedSizeGroup ?? ""} onValueChange={onSelect}>
            <SelectTrigger className="w-full h-14 border-2 border-gray-100 bg-white px-4 pr-10 flex items-center text-sm font-semibold shadow-sm">
              <SelectValue placeholder="Select size group" />
            </SelectTrigger>

            <SelectContent>
              {sizeGroups.map((group) => (
                <SelectItem key={group} value={group}>
                  {group}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>

          {/*<div className="pointer-events-none absolute right-4 top-1/2 -translate-y-1/2 text-gray-400">
            <ChevronDown size={18} />
          </div>*/}
        </div>
      ) : (
        <div className="w-full h-14 rounded-2xl border-2 border-gray-100 bg-gray-50 px-4 flex items-center text-gray-400 font-medium">
          No sizes available
        </div>
      )}

      {selectedSizeGroup && (
        <div className="mt-3 flex items-center justify-between text-xs font-bold uppercase tracking-wider px-2">
          <span className="text-gray-400">Available Sets</span>

          <span
            className={`${
              availableStock === 0
                ? "text-rose-500"
                : availableStock < 5 && "text-amber-500"
            }`}
          >
            {availableStock}
          </span>
        </div>
      )}
    </div>
  );
}
