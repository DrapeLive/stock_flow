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
import FilterToggle from "@/components/ui/FilterToggle";

type ItemTypeTab = "gents" | "kids";

export default function Home() {
  const [data, setData] = useState<OrderAllResponse>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(false);
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");
  const [showFilters, setShowFilters] = useState(false);
  const [activeTab, setActiveTab] = useState<ItemTypeTab>("gents");
  const router = useRouter();

  useEffect(() => {
    setLoading(true);
    const fetchData = async () => {
      try {
        const response = await orderApi.getAll({
          from: fromDate || undefined,
          to: toDate || undefined,
        });
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

  const filteredOrders = pendingPacked.filter((order) =>
    order.items.some((item) => item.item_type === activeTab),
  );

  const order_len = filteredOrders.length;

  const handleClearFilters = () => {
    setFromDate("");
    setToDate("");
    setShowFilters(false);
  };

  const handleToggleFilters = () => {
    if (showFilters) {
      handleClearFilters();
    } else {
      setShowFilters(true);
    }
  };

  if (loading) return <PageLoading />;
  if (loadError) return null;

  return (
    <div className="min-h-screen min-w-full">
      <OrderListHeader
        title="Remaining Orders"
        count={order_len}
        showFilters={showFilters}
        handleToggleFilters={handleToggleFilters}
      />

      <div className="flex gap-2 bg-white px-4 py-3 sticky top-0 z-10">
        {(["gents", "kids"] as ItemTypeTab[]).map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-5 py-1.5 rounded-full text-sm font-semibold capitalize transition-colors ${
              activeTab === tab
                ? "bg-black text-white"
                : "text-gray-500 hover:text-gray-700"
            }`}
          >
            {tab.charAt(0).toUpperCase() + tab.slice(1)}
          </button>
        ))}
      </div>

      <FilterBar
        fromDate={fromDate}
        toDate={toDate}
        onFromDateChange={setFromDate}
        onToDateChange={setToDate}
        isOpen={showFilters}
        onClear={handleClearFilters}
      />

      {order_len === 0 ? (
        <EmptyState title="No Active Orders" />
      ) : (
        <div className="space-y-3 pb-32">
          {filteredOrders.map((order) => (
            <OrderCard
              key={order.id}
              order={order}
              onClick={() => router.push(`/agent/order/status/${order.id}`)}
            />
          ))}
        </div>
      )}
    </div>
  );
}
