"use client";

import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { useAuth } from "@/context/AuthContext";
import { itemApi } from "@/lib/api/item";
import { VariantAllItem } from "@/types/item";
import { Info, Plus, Printer } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

const ListItems: React.FC = () => {
  const { isAuthenticated } = useAuth();
  const [data, setData] = useState<VariantAllItem[]>([]);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    setLoading(true);
    itemApi
      .getAllVariants()
      .then(setData)
      .catch((e) => console.error("Error fetching variants:", e))
      .finally(() => setLoading(false));
  }, [isAuthenticated, router]);

  if (loading) {
    return <h2 className="flex justify-center">Loading</h2>;
  }

  if (data.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[50vh] gap-4">
        <h2 className="text-xl font-bold text-gray-400">No Variants</h2>
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
              Total Variants
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
        {data.map((variant) => {
          return (
            <div
              key={variant.id}
              className="flex items-center gap-4 bg-white border border-gray-100 p-3 hover:border-primary/30 hover:shadow-md transition-all rounded-2xl group cursor-pointer"
              onClick={() => router.push(`/admin/items/edit/${variant.item_id}`)}
            >
              {/* Thumbnail */}
              <div className="w-16 h-16 rounded-xl bg-gray-50 overflow-hidden flex-shrink-0 border border-gray-100 shadow-sm">
                {variant.image ? (
                  <img
                    src={variant.image}
                    alt={variant.item_name}
                    className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-300"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center">
                    <Info className="size-6 text-gray-300 opacity-40" />
                  </div>
                )}
              </div>

              {/* Details */}
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <h6 className="font-bold text-gray-900 text-base truncate leading-tight">
                    {variant.item_name}
                  </h6>
                  {variant.item_type && (
                    <span className="text-[9px] bg-gray-100 text-gray-500 px-1.5 py-0.5 rounded-md uppercase font-bold tracking-tighter border border-gray-200 flex-shrink-0">
                      {variant.item_type}
                    </span>
                  )}
                </div>

                <p className="text-xs text-gray-400 truncate mt-1 leading-tight font-medium">
                  QR: {variant.qr_code || "N/A"}
                </p>

                {/* Size chips */}
                <div className="flex -space-x-1.5 overflow-hidden mt-2">
                  {variant.unique_sizes.slice(0, 3).map((size, i) => (
                    <div
                      key={i}
                      className="inline-flex items-center justify-center h-5 px-1.5 rounded-md bg-gray-50 border border-white text-[9px] font-bold text-gray-400 shadow-sm"
                    >
                      {size}
                    </div>
                  ))}
                  {variant.unique_sizes.length > 3 && (
                    <div className="inline-flex items-center justify-center h-5 px-1.5 rounded-md bg-gray-50 border border-white text-[9px] font-bold text-gray-300">
                      +{variant.unique_sizes.length - 3}
                    </div>
                  )}
                </div>
              </div>

              {/* Stock */}
              <div className="flex flex-col items-end justify-center px-4 border-l border-gray-50">
                <span className="text-[10px] text-gray-300 font-bold uppercase tracking-widest leading-none mb-1">
                  Stock
                </span>
                <span
                  className={`text-lg font-black leading-none ${
                    variant.total_stock < 10 ? "text-amber-500" : "text-gray-900"
                  }`}
                >
                  {variant.total_stock}
                </span>
              </div>

              {/* Print QR */}
              {variant.qr_code && (
                <div className="flex items-center gap-1 pl-2">
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      window.open("/admin/items/qr/" + variant.qr_code, "_blank");
                    }}
                    className="p-2 text-gray-300 hover:text-primary hover:bg-primary/5 rounded-xl transition-all border border-transparent hover:border-primary/10"
                    title="Print QR"
                  >
                    <Printer className="size-5" />
                  </button>
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
