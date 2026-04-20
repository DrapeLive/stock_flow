"use client";

import { useAuth } from "@/context/AuthContext";
import { orderApi } from "@/lib/api/order";
import { OrderAllResponse } from "@/types/order";
import { Filter, Info } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { OrderCard } from "@/components/order";
import { OrderFilters } from "./types";

interface Props {
  filters?: OrderFilters;
}

const All: React.FC<Props> = ({ filters }) => {
  const { isAuthenticated } = useAuth();

  const [data, setData] = useState<OrderAllResponse>([]);
  const [loading, setLoading] = useState(true);

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await orderApi.getAll(filters);
        const sorted = [...response].sort(
          (a, b) =>
            new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
        );
        setData(sorted);
      } catch (error) {
        console.error("Error fetching data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [isAuthenticated, router, filters]);

  if (loading)
    return (
      <p className="text-center py-10 text-gray-400 font-medium">
        Loading orders...
      </p>
    );
  if (data.length == 0)
    return (
      <div className="flex flex-col items-center justify-center py-20 text-gray-300">
        <Info size={40} className="mb-4 opacity-20" />
        <h2 className="text-xl font-bold">No Data Found</h2>
      </div>
    );

  return (
    <>
      <div className="pt-2 flex justify-between items-center px-2 mb-4">
        <div className="flex gap-2 items-center">
          <span className="text-gray-400 text-[10px] font-bold uppercase tracking-wider">
            Total Orders
          </span>
          <div className="bg-gray-100 text-gray-500 rounded-full py-0.5 px-3 border border-gray-200">
            <span className="font-bold text-xs">{data.length}</span>
          </div>
        </div>
        <button className="p-2 rounded-xl border border-gray-100 bg-white hover:bg-gray-50 transition-colors shadow-sm">
          <Filter className="text-gray-400 size-4" />
        </button>
      </div>

      <div className="space-y-3 pb-20">
        {data?.map((order) => (
          <OrderCard key={order.id} order={order} />
        ))}
      </div>
    </>
  );
};

export default All;
