"use client";
import { useEffect, useState, useCallback } from "react";
import { useParams } from "next/navigation";
import { orderApi } from "@/lib/api/order";
import { OrderResponse } from "@/types/order";
import OrderTabs, { Tab } from "@/components/pages/order/OrderTabs";
import OrderSummary from "@/components/pages/order/OrderSummary";
import OrderItemsSection from "@/components/pages/order/OrderItemsSection";
import OrderFooter from "@/components/pages/order/OrderFooter";
import OrderDetailHeader from "@/components/pages/admin/order-item/OrderDetailHeader";

export default function Page() {
  const params = useParams();
  const id = params.id as string;

  const [activeTab, setActiveTab] = useState<Tab>("Packing");
  const [loading, setLoading] = useState(false);
  const [data, setData] = useState<OrderResponse>();
  const [isPackingMode, setIsPackingMode] = useState(false);

  const fetchData = useCallback(async () => {
    try {
      const response = await orderApi.getOne(Number(id));
      setData(response);
    } catch (error) {
      console.error("Error fetching data:", error);
    }
  }, [id]);

  useEffect(() => {
    setLoading(true);
    fetchData().finally(() => setLoading(false));
  }, [fetchData]);

  const handlePackedChange = () => {
    fetchData();
  };

  const handleUpdateStatus = async (newStatus: "PACKED" | "DISPATCHED") => {
    try {
      setLoading(true);
      if (newStatus === "DISPATCHED") {
        await orderApi.dispatchOrder(Number(id));
      } else {
        await orderApi.update(Number(id), { status: newStatus });
      }
      await fetchData();
      if (newStatus === "PACKED") setIsPackingMode(false);
    } catch (err) {
      console.error("Error updating status:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleTabChange = (tab: Tab) => {
    setActiveTab(tab);
    setIsPackingMode(false);
  };

  const allItemsPacked = data?.items.every(
    (item) => item.packed_quantity! >= item.quantity
  );

  if (loading && !data) return <h2 className="flex justify-center mt-10">Loading...</h2>;

  return (
    <div className="min-h-screen bg-white pb-20">
      <OrderDetailHeader orderId={id} backHref="/admin" />

      <div className="px-4 pt-4 max-w-4xl mx-auto">
        <OrderTabs activeTab={activeTab} onTabChange={handleTabChange} />

        <OrderSummary
          customerName={data?.customer_details.name ?? ""}
          agentName={data?.agent_details.username ?? ""}
          orderDate={data?.created_at?.slice(0, 10) ?? ""}
          status={data?.status ?? ""}
        />

        <OrderItemsSection
          items={data?.items}
          activeTab={activeTab}
          isPackingMode={isPackingMode}
          onPackedChange={handlePackedChange}
          onTogglePackingMode={() => setIsPackingMode(!isPackingMode)}
          status={data?.status}
        />
      </div>

      <OrderFooter
        activeTab={activeTab}
        status={data?.status}
        allItemsPacked={!!allItemsPacked}
        onUpdateStatus={handleUpdateStatus}
      />
    </div>
  );
}
