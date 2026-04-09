"use client";

import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { useAuth } from "@/context/AuthContext";
import { itemApi } from "@/lib/api/item";
import { ItemStockEntry } from "@/types/item";
import { ChevronDown, ChevronRight, Eye, Info, Plus, Printer } from "lucide-react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

const ListItems: React.FC = () => {
  const { isAuthenticated } = useAuth();
  const [data, setData] = useState<ItemStockEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedId, setExpandedId] = useState<number | null>(null);
  const router = useRouter();

  useEffect(() => {
    itemApi
      .getStockList()
      .then(setData)
      .catch((e) => console.error("Error fetching items:", e))
      .finally(() => setLoading(false));
  }, [isAuthenticated]);

  const toggleExpand = (id: number) => {
    setExpandedId(expandedId === id ? null : id);
  };

  if (loading) {
    return <h2 className="flex justify-center">Loading</h2>;
  }

  if (data.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[50vh] gap-4">
        <h2 className="text-xl font-bold text-gray-400">No Items</h2>
        <StockFlowButton
          text="Add Item"
          icon={<Plus className="size-4" />}
          onClick={() => router.push("/admin/items/new")}
          className="shadow-lg shadow-primary/20"
        />
      </div>
    );
  }

  return (
    <>
      {/* Header */}
      <div className="pt-6 pb-8 flex justify-between items-center px-6">
        <div className="flex flex-col">
          <h1 className="text-2xl font-extrabold text-gray-900">Inventory</h1>
          <div className="flex gap-2 items-center mt-1">
            <span className="text-gray-400 text-xs font-bold uppercase tracking-wider">
              Total Items
            </span>
            <div className="bg-primary/10 text-primary rounded-full py-0.5 px-3 border border-primary/20">
              <span className="font-bold text-xs">{data.length}</span>
            </div>
          </div>
        </div>
        <StockFlowButton
          text="Add Item"
          icon={<Plus className="size-4" />}
          onClick={() => router.push("/admin/items/new")}
          className="shadow-lg shadow-primary/20"
        />
      </div>

      {/* List */}
      <div className="px-4 space-y-2">
        {data.map((item) => {
          const isExpanded = expandedId === item.id;
          const variantCount = item.variants.length;

          return (
            <div key={item.id} className="space-y-1">
              {/* Main row */}
              <div
                className="flex items-center gap-3 bg-white border border-gray-100 p-3 hover:border-primary/30 hover:shadow-md transition-all rounded-2xl cursor-pointer"
                onClick={() => toggleExpand(item.id)}
              >
                {/* Thumbnail */}
                <div className="relative w-14 h-14 rounded-xl bg-gray-50 overflow-hidden flex-shrink-0 border border-gray-100 shadow-sm">
                  {item.image ? (
                    <Image
                      src={item.image}
                      alt={item.name}
                      fill
                      className="object-cover"
                      unoptimized
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center">
                      <Info className="size-5 text-gray-300 opacity-40" />
                    </div>
                  )}
                </div>

                {/* Details */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <h6 className="font-bold text-gray-900 text-base truncate leading-tight">
                      {item.name}
                    </h6>
                    {item.type && (
                      <span className="text-[9px] bg-gray-100 text-gray-500 px-1.5 py-0.5 rounded-md uppercase font-bold tracking-tighter border border-gray-200 flex-shrink-0">
                        {item.type}
                      </span>
                    )}
                  </div>

                  <p className="text-xs text-gray-400 mt-1 leading-tight font-medium">
                    {variantCount} variant{variantCount !== 1 ? "s" : ""}
                  </p>
                </div>

                {/* Actions */}
                <div className="flex items-center gap-1">
                  {/* Eye - Edit button */}
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      router.push(`/admin/items/edit/${item.id}`);
                    }}
                    className="p-2.5 bg-gray-100 text-gray-500 hover:bg-primary hover:text-white rounded-xl transition-all"
                    title="Edit Item"
                  >
                    <Eye className="size-5" />
                  </button>

                  {/* Print button */}
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      window.open(`/admin/items/qr-print/${item.id}`, "_blank");
                    }}
                    className="p-2.5 bg-gray-100 text-gray-500 hover:bg-primary hover:text-white rounded-xl transition-all"
                    title="Print All QR Codes"
                  >
                    <Printer className="size-5" />
                  </button>

                  {/* Expand/Collapse */}
                  {isExpanded ? (
                    <div className="p-2.5 bg-gray-100 rounded-xl">
                      <ChevronDown className="size-5 text-gray-500" />
                    </div>
                  ) : (
                    <div className="p-2.5 bg-gray-100 rounded-xl">
                      <ChevronRight className="size-5 text-gray-500" />
                    </div>
                  )}
                </div>
              </div>

              {/* Expanded variants */}
              {isExpanded && (
                <div className="pl-4 space-y-1">
                  {item.variants.map((variant, index) => (
                    <div
                      key={variant.id}
                      className="flex items-center gap-3 bg-gray-50/70 border border-gray-100 p-3 rounded-xl"
                    >
                      {/* Variant image */}
                      <div className="relative w-12 h-12 rounded-lg bg-white overflow-hidden flex-shrink-0 border border-gray-200 shadow-sm">
                        {variant.image ? (
                          <Image
                            src={variant.image}
                            alt={`Variant ${index + 1}`}
                            fill
                            className="object-cover"
                            unoptimized
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center">
                            <Printer className="size-4 text-gray-300" />
                          </div>
                        )}
                      </div>

                      {/* Variant details */}
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-semibold text-gray-700 truncate">
                          Variant #{index + 1}
                        </p>
                        <p className="text-xs text-gray-400">
                          {variant.sizes.map((s) => s.size).join(", ")} • QR: {variant.qr_code?.slice(0, 8) || "N/A"}...
                        </p>
                      </div>

                      {/* Stock */}
                      <div className="text-right pr-2">
                        <span className="text-sm font-bold text-gray-700">
                          {variant.total_stock}
                        </span>
                        <span className="text-xs text-gray-400 block">in stock</span>
                      </div>

                      {/* Print button */}
                      <button
                        type="button"
                        onClick={() => {
                          if (variant.qr_code) {
                            window.open(`/admin/items/qr/${variant.qr_code}`, "_blank");
                          }
                        }}
                        disabled={!variant.qr_code}
                        className="p-2.5 bg-primary text-white hover:bg-primary/90 rounded-xl transition-all disabled:opacity-40 disabled:cursor-not-allowed"
                        title="Print QR"
                      >
                        <Printer className="size-4" />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </>
  );
};

export default ListItems;
