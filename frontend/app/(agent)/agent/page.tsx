"use client";

import { useEffect, useState } from "react";
import { orderApi } from "@/lib/api/order";
import { toastError } from "@/lib/toast";
import { OrderAllResponse } from "@/types/order";
import groupOrders from "@/util/groupOrders";
import { PageLoading } from "@/components/ui/Loading";
import { useRouter } from "next/navigation";
import OrderCard from "@/components/pages/agent/order/OrderCard";
import OrderListHeader from "@/components/pages/agent/order/OrderListHeader";
import EmptyState from "@/components/ui/EmptyState";
import FilterBar from "@/components/ui/FilterBar";

export default function Home() {
  const [data, setData] = useState<OrderAllResponse>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(false);
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await orderApi.getAll({ from: fromDate || undefined, to: toDate || undefined });
        setData(response);
      } catch (e) {
        console.error("Error fetching orders:", e);
        toastError("Failed to fetch orders", e);
        setLoadError(true);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [fromDate, toDate]);

  const sortedData = [...data].sort(
    (a, b) =>
      new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
  );

  const { pendingPacked } = groupOrders(sortedData);
  const order_len = pendingPacked.length;

  if (loading) return <PageLoading />;
  if (loadError) return null;
  if (order_len === 0) return <EmptyState title="No Active Orders" />;

  return (
    <div className="min-h-screen min-w-full px-4 bg-gray-50/30">
      <OrderListHeader title="Remaining Orders" count={order_len} />
      <FilterBar
        fromDate={fromDate}
        toDate={toDate}
        onFromDateChange={setFromDate}
        onToDateChange={setToDate}
      />

      <div className="space-y-3 pb-32">
        {pendingPacked?.map((order) => (
          <OrderCard
            key={order.id}
            order={order}
            onClick={() => router.push(`/agent/order/status/${order.id}`)}
          />
        ))}
      </div>
    </div>
  );
}
