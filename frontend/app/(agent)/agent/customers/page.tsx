"use client";

import { useAuth } from "@/context/AuthContext";
import { Info, ArrowLeft } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { CustomerAllResponse } from "@/types/customer";
import { customerApi } from "@/lib/api/customer";
import { PageLoading } from "@/components/ui/Loading";

export default function AgentCustomersPage() {
  const { user, isAuthenticated } = useAuth();
  const [data, setData] = useState<CustomerAllResponse>([]);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await customerApi.getAll();
        setData(response);
      } catch (error) {
        console.error("Error fetching customers:", error);
      } finally {
        setLoading(false);
      }
    };

    if (isAuthenticated) {
      fetchData();
    }
  }, [isAuthenticated]);

  if (loading) return <PageLoading />;

  return (
    <div className="min-h-screen bg-gray-50/50 pb-20">
      {/* Header */}
      <div className="bg-white border-b border-gray-100 px-6 py-6 sticky top-0 z-10">
        <div className="max-w-md mx-auto flex items-center gap-4">
          <button 
            onClick={() => router.back()}
            className="p-2 rounded-xl hover:bg-gray-50 text-gray-400 transition-colors"
          >
            <ArrowLeft size={20} />
          </button>
          <div className="flex flex-col">
            <h1 className="text-xl font-black text-gray-900 leading-tight">My Customers</h1>
            <div className="flex gap-2 items-center mt-1">
              <span className="text-gray-400 text-[10px] font-bold uppercase tracking-wider">Total Linked</span>
              <div className="bg-primary/10 text-primary rounded-full py-0.5 px-3 border border-primary/20">
                <span className="font-bold text-xs">{data.length}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-md mx-auto px-6 pt-6">
        {data.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 text-gray-300">
            <Info size={40} className="mb-4 opacity-20" />
            <h2 className="text-xl font-bold">No Customers Found</h2>
            <p className="text-sm text-gray-400 mt-1">You haven't been assigned any customers yet.</p>
          </div>
        ) : (
          <div className="space-y-3 pb-10">
            {data.map((item) => (
              <div
                key={item.id}
                className="flex items-center gap-4 bg-white border border-gray-100 p-4 hover:border-primary/30 hover:shadow-md transition-all rounded-2xl group active:scale-[0.98]"
              >
                <div className="w-12 h-12 rounded-xl bg-gray-50 flex items-center justify-center border border-gray-100 shadow-sm flex-shrink-0">
                  <span className="text-xl font-black text-gray-400 opacity-30">
                    {item.name.charAt(0).toUpperCase()}
                  </span>
                </div>

                <div className="flex-1 min-w-0">
                  <h6 className="font-bold text-gray-900 text-base truncate leading-tight">
                    {item.name}
                  </h6>
                  <p className="text-xs text-gray-400 truncate mt-1 leading-tight font-medium">
                    {item.address || "No address provided"}
                  </p>
                </div>

                <div className="flex flex-col items-end justify-center px-4 border-l border-gray-50">
                  <span className="text-[10px] text-gray-300 font-bold uppercase tracking-widest mb-1">Orders</span>
                  <span className="text-lg font-black leading-none text-gray-900">
                    {item.total_orders}
                  </span>
                </div>

                <div className="text-gray-200 group-hover:text-primary/30 transition-colors pl-2">
                  <Info size={18} />
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
