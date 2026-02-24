"use client";
import { Button } from "@/components/ui/button";
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

    const fetchData = async () => {
      try {
        const response = await itemApi.getAll();
        setData(response);
      } catch (error) {
        console.error("Error fetching data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [isAuthenticated, router]);

  if (loading) {
    return <h2 className="flex justify-center">Loading</h2>;
  }
  if (data.length == 0)
    return <h2 className="flex justify-center">No Items</h2>;
  return (
    <>
      <div className="pt-4 pb-6 flex justify-between items-center px-4">
        <div className="flex gap-2 items-center">
          <span className="text-gray-500 text-sm font-medium">Total Items</span>
          <div className="bg-primary/10 text-primary rounded-full py-0.5 px-3 border border-primary/20">
            <span className="font-bold text-sm">{data.length}</span>
          </div>
        </div>
        <StockFlowButton
          text="Add Item"
          icon={<Plus className="size-4" />}
          onClick={() => router.push("/admin/items/new")}
        />
      </div>
      <div className="px-2 sm:px-4 space-y-1">
        {data?.map((item, index) => {
          const firstImage = item.variants?.find((v) => v.image)?.image;

          return (
            <div
              className="flex items-center gap-3 border-b border-gray-100 py-3 hover:bg-gray-50/50 transition-colors rounded-lg px-2 group"
              key={index}
            >
              {/* Image Section */}
              <div className="w-12 h-12 rounded-lg bg-gray-50 overflow-hidden flex-shrink-0 border border-gray-100">
                {firstImage ? (
                  <img
                    src={firstImage}
                    alt={item.name}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-gray-400">
                    <Info className="size-5 opacity-20" />
                  </div>
                )}
              </div>

              {/* Details Section */}
              <div className="flex-1 min-w-0 flex flex-col justify-center">
                <h6 className="font-bold text-gray-900 text-sm sm:text-base truncate leading-tight">
                  {item.name}
                </h6>
                <p className="text-xs text-gray-500 truncate mt-0.5 leading-tight">
                  {item.description || "No description"}
                </p>
                <div className="flex items-center gap-1.5 mt-1">
                  <span className="text-[9px] bg-primary/5 text-primary px-1 py-0.5 rounded uppercase font-semibold border border-primary/10">
                    {item.type}
                  </span>
                </div>
              </div>

              {/* Stock Info Section */}
              <div className="flex flex-col items-center justify-center px-2 sm:px-4 border-l border-gray-50 h-8 min-w-[60px] sm:min-w-[80px]">
                <span className="text-[10px] text-gray-400 font-medium uppercase tracking-wider">Stock</span>
                <span className="text-sm font-bold text-gray-900 leading-none">
                  {item.sizes.reduce(
                    (total, sizeInfo) => total + sizeInfo.stock,
                    0
                  )}
                </span>
              </div>

              {/* Attributes Section (Hidden on small screens) */}
              <div className="hidden lg:flex flex-col gap-1 items-start justify-center min-w-32 px-4 border-l border-gray-50">
                <div className="flex flex-wrap gap-1">
                  {item.sizes.slice(0, 3).map((s, i) => (
                    <span key={i} className="text-[10px] text-gray-500 bg-gray-50 px-1 rounded">
                      {s.size}
                    </span>
                  ))}
                  {item.sizes.length > 3 && (
                    <span className="text-[10px] text-gray-400">
                      +{item.sizes.length - 3}
                    </span>
                  )}
                </div>
              </div>

              {/* Actions Section */}
              <div className="flex items-center gap-1 pl-2">
                <button
                  onClick={() => router.push("/admin/items/qr/" + item.id)}
                  className="p-1.5 text-gray-400 hover:text-primary hover:bg-primary/5 rounded-lg transition-all border border-transparent hover:border-primary/10"
                  title="Print QR"
                >
                  <Printer className="size-4 sm:size-5" />
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </>
  );
};

export default ListItems;
