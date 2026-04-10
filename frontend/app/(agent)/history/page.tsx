"use client";

import { PageLoading } from "@/components/ui/Loading";
import { orderApi } from "@/lib/api/order";
import { toastError } from "@/lib/toast";
import { OrderAllResponse } from "@/types/order";
import groupOrders from "@/util/groupOrders";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import OrderCard from "@/components/pages/agent/order/OrderCard";
import OrderListHeader from "@/components/pages/agent/order/OrderListHeader";
import EmptyState from "@/components/ui/EmptyState";

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
        console.error("Error fetching orders:", e);
        toastError("Server Not Found", e);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  const { dispatched } = groupOrders(data ?? []);
  const order_len = dispatched.length;

  if (loading) return <PageLoading />;
  if (order_len === 0) return <EmptyState title="No Dispatched Orders" />;

  return (
    <div className="min-h-screen min-w-full px-4 bg-gray-50/30">
      <OrderListHeader 
        title="Dispatched Orders" 
        count={order_len} 
        countColor="green" 
      />

      <div className="space-y-3 pb-32">
        {dispatched?.map((order) => (
          <OrderCard
            key={order.id}
            order={order}
            onClick={() => router.push(`/order/status/${order.id}`)}
          />
        ))}
      </div>
    </div>
  );
}
