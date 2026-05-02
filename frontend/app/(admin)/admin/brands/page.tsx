"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";
import { brandApi } from "@/lib/api/brand";
import { BrandAllResponse } from "@/types/brand";
import { Info, Plus, Store } from "lucide-react";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";

export default function BrandsPage() {
  const { isSuperuser } = useAuth();
  const [data, setData] = useState<BrandAllResponse>([]);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    if (!isSuperuser) {
      router.push("/admin");
      return;
    }

    const fetchData = async () => {
      try {
        const response = await brandApi.getAll();
        setData(response);
      } catch (error) {
        console.error("Error fetching brands:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [isSuperuser, router]);

  if (!isSuperuser) return null;

  if (loading) {
    return <h2 className="flex justify-center">Loading</h2>;
  }

  if (data.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[50vh] gap-4 px-4">
        <Store size={48} className="text-gray-300" />
        <h2 className="text-xl font-bold text-gray-400">No Brands</h2>
        <StockFlowButton
          text="Add Brand"
          variant="filled"
          icon={<Plus className="size-4" />}
          onClick={() => router.push("/admin/brands/new")}
          className="shadow-lg shadow-primary/20 ring-1 ring-primary/10"
        />
      </div>
    );
  }

  return (
    <div className="min-h-screen min-w-full px-0">
      <div className="pt-2 flex justify-between items-center px-4 mb-6">
        <div className="flex flex-col">
          <h2 className="text-xl font-extrabold text-gray-900 leading-tight">
            Brands
          </h2>
          <div className="flex gap-2 items-center mt-1">
            <span className="text-gray-400 text-[10px] font-bold uppercase tracking-wider">
              Total Brands
            </span>
            <div className="bg-primary/10 text-primary rounded-full py-0.5 px-3 border border-primary/20">
              <span className="font-bold text-xs">{data.length}</span>
            </div>
          </div>
        </div>
        <StockFlowButton
          text="Add Brand"
          variant="filled"
          icon={<Plus className="size-4" />}
          onClick={() => router.push("/admin/brands/new")}
          className="shadow-lg shadow-primary/20 ring-1 ring-primary/10"
        />
      </div>
      <div className="px-4 space-y-3 pb-20">
        {data.map((brand) => (
          <div
            key={brand.id}
            onClick={() => router.push(`/admin/brands/${brand.id}`)}
            className="flex items-center gap-4 bg-white border border-gray-100 p-4 hover:border-primary/30 hover:shadow-md transition-all rounded-2xl group cursor-pointer active:scale-[0.98]"
          >
            <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0 overflow-hidden">
              {brand.logo_url ? (
                <img
                  src={brand.logo_url}
                  alt={brand.name}
                  className="w-full h-full object-cover"
                />
              ) : (
                <Store size={20} className="text-primary" />
              )}
            </div>

            <div className="flex-1 min-w-0 px-2">
              <h6 className="font-bold text-gray-900 text-base truncate leading-tight">
                {brand.name}
              </h6>
              <p className="text-xs text-gray-400 truncate mt-1 leading-tight font-medium">
                {brand.email}
              </p>
            </div>

            <div className="text-gray-200 group-hover:text-primary/30 transition-colors pl-2">
              <Info size={18} />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
