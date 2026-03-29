"use client";

import { AlertDestructive } from "@/components/ui/AlertDestructive";
import { PageLoading } from "@/components/ui/Loading";
import { orderApi } from "@/lib/api/order";
import { OrderAllResponse } from "@/types/order";
import groupOrders from "@/util/groupOrders";
import { Filter, Info } from "lucide-react";
import Image from "next/image";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import StatusBadge from "@/components/ui/custom/StatusBadge";

export default function History() {
  const [data, setData] = useState<OrderAllResponse>([]);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await orderApi.getAll();
        setData(response);
      } catch (e) {
        <AlertDestructive heading="Error" description={"Server Not Found"} />;
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  const { dispatched } = groupOrders(data ?? []);

  const order_len = dispatched.length;

  if (loading) return <PageLoading />;

  if (order_len == 0) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-gray-300">
        <Info size={40} className="mb-4 opacity-20" />
        <h2 className="text-xl font-bold">No Dispatched Orders</h2>
      </div>
    );
  }

  return (
    <div className="min-h-screen min-w-full px-4 bg-gray-50/30">
      <div className="pt-4 flex justify-between items-center mb-6">
        <div className="flex gap-2 items-center">
          <span className="text-gray-400 text-[10px] font-bold uppercase tracking-wider">Dispatched Orders</span>
          <div className="bg-green-100 text-green-600 rounded-full py-0.5 px-3 border border-green-200">
            <span className="font-bold text-xs">{order_len}</span>
          </div>
        </div>
        <button className="p-2 rounded-xl border border-gray-100 bg-white hover:bg-gray-50 transition-colors shadow-sm">
          <Filter className="text-gray-400 size-4" />
        </button>
      </div>

      <div className="space-y-3 pb-32">
        {dispatched?.map((order) => {
          const previewImages = order.items.slice(0, 3);

          return (
            <div 
              key={order.id} 
              className="flex items-center p-4 bg-white border border-gray-100 hover:border-primary/30 hover:shadow-md transition-all cursor-pointer rounded-2xl group"
              onClick={() => router.push(`/admin/order/status/${order.id}`)}
            >
              <div className="relative w-16 h-16 flex-shrink-0">
                {previewImages[0]?.item.variants[0]?.image && (
                  <div className="absolute left-0 z-30 rotate-0">
                    <Image
                      src={previewImages[0].item.variants[0].image}
                      alt={previewImages[0].item.name}
                      width={56}
                      height={56}
                      className="rounded-xl object-cover border-2 border-white shadow-sm bg-white"
                      unoptimized
                    />
                  </div>
                )}
                {previewImages[1]?.item.variants[0]?.image && (
                  <div className="absolute left-0 z-20 rotate-10 scale-95 opacity-80">
                    <Image
                      src={previewImages[1].item.variants[0].image}
                      alt={previewImages[1].item.name}
                      width={56}
                      height={56}
                      className="rounded-xl object-cover border-2 border-white shadow-sm bg-white"
                      unoptimized
                    />
                  </div>
                )}
                {previewImages[2]?.item.variants[0]?.image && (
                  <div className="absolute left-0 z-10 rotate-20 scale-90 opacity-60">
                    <Image
                      src={previewImages[2].item.variants[0].image}
                      alt={previewImages[2].item.name}
                      width={56}
                      height={56}
                      className="rounded-xl object-cover border-2 border-white shadow-sm bg-white"
                      unoptimized
                    />
                  </div>
                )}
              </div>

              <div className="flex-1 flex flex-col px-4 justify-center min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <h6 className="font-bold text-gray-900 text-base truncate leading-tight">
                    {order.customer_details.name}
                  </h6>
                </div>
                <p className="text-xs text-gray-400 font-medium truncate">
                  {order.items.map((item, i) => (
                    <span key={item.id}>
                      {item.item.name}{i < order.items.length - 1 ? ", " : ""}
                    </span>
                  ))}
                </p>
              </div>

              <div className="flex flex-col items-end gap-2 pr-2">
                <StatusBadge status={order.status} />
                <div className="flex flex-col items-end">
                  <h3 className="text-lg font-black leading-none text-gray-900">{order.total_quantity}</h3>
                  <p className="text-[9px] text-gray-300 font-bold uppercase tracking-tighter">Pieces</p>
                </div>
              </div>

              <div className="flex items-center pl-4 border-l border-gray-50 text-gray-200 group-hover:text-primary/30 transition-colors">
                <Info size={18} />
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
