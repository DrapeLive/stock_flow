"use client";

import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { useAuth } from "@/context/AuthContext";
import { itemApi } from "@/lib/api/item";
import { ItemAllResponse } from "@/types/item";
import { Info, Plus, Printer } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

const ListItems: React.FC = () => {
  const { isAuthenticated } = useAuth();
  const [data, setData] = useState<ItemAllResponse>([]);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    setLoading(true);
    itemApi
      .getAll()
      .then(setData)
      .catch((e) => console.error("Error fetching items:", e))
      .finally(() => setLoading(false));
  }, [isAuthenticated, router]);

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
        {data.map((item, index) => {
          const variants = item.variants ?? [];
          const firstImage = variants.find((v) => v.image)?.image;
          const totalStock = variants.reduce(
            (sum, v) => sum + v.sizes.reduce((s, size) => s + size.stock, 0),
            0,
          );
          // Show up to 3 unique sizes
          const uniqueSizes = [...new Set(variants.flatMap((v) => v.sizes.map((s) => s.size)))];
          // qr_code lives on variants; use the first one for the print action
          const firstQr = variants[0]?.qr_code;

          return (
            <div
              key={index}
              className="flex items-center gap-4 bg-white border border-gray-100 p-3 hover:border-primary/30 hover:shadow-md transition-all rounded-2xl group cursor-pointer"
              onClick={() => router.push(`/admin/items/edit/${item.id}`)}
            >
              {/* Thumbnail */}
              <div className="w-16 h-16 rounded-xl bg-gray-50 overflow-hidden flex-shrink-0 border border-gray-100 shadow-sm">
                {firstImage ? (
                  <img
                    src={firstImage}
                    alt={item.name}
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
                    {item.name}
                  </h6>
                  {item.type && (
                    <span className="text-[9px] bg-gray-100 text-gray-500 px-1.5 py-0.5 rounded-md uppercase font-bold tracking-tighter border border-gray-200 flex-shrink-0">
                      {item.type}
                    </span>
                  )}
                </div>

                <p className="text-xs text-gray-400 truncate mt-1 leading-tight font-medium">
                  {item.description || "No description"}
                </p>

                {/* Size chips */}
                <div className="flex -space-x-1.5 overflow-hidden mt-2">
                  {uniqueSizes.slice(0, 3).map((size, i) => (
                    <div
                      key={i}
                      className="inline-flex items-center justify-center h-5 px-1.5 rounded-md bg-gray-50 border border-white text-[9px] font-bold text-gray-400 shadow-sm"
                    >
                      {size}
                    </div>
                  ))}
                  {uniqueSizes.length > 3 && (
                    <div className="inline-flex items-center justify-center h-5 px-1.5 rounded-md bg-gray-50 border border-white text-[9px] font-bold text-gray-300">
                      +{uniqueSizes.length - 3}
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
                    totalStock < 10 ? "text-amber-500" : "text-gray-900"
                  }`}
                >
                  {totalStock}
                </span>
              </div>

              {/* Print QR */}
              {firstQr && (
                <div className="flex items-center gap-1 pl-2">
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      window.open("/admin/items/qr/" + firstQr, "_blank");
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
