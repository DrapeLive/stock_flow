"use client";
import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { orderApi } from "@/lib/api/order";
import { OrderResponse } from "@/types/order";
import OrderDetailHeader from "@/components/pages/agent/order/OrderDetailHeader";
import OrderDetailSummary from "@/components/pages/agent/order/OrderDetailSummary";
import OrderDetailItems from "@/components/pages/agent/order/OrderDetailItems";

export default function Page() {
  const params = useParams();
  const id = params.id as string;
  const router = useRouter();

  const [loading, setLoading] = useState(true);
  const [data, setData] = useState<OrderResponse>();

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await orderApi.getOne(Number(id));
        setData(response);
      } catch (error) {
        console.error("Error fetching data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [id]);

  const handleViewInvoice = () => {
    localStorage.setItem("orderKey", id);
    router.push("/order/invoice");
  };

  if (loading) return <h2 className="flex justify-center mt-10">Loading...</h2>;

  return (
    <div className="min-h-screen bg-white pb-6">
      <OrderDetailHeader orderId={id} backHref="/" onViewInvoice={handleViewInvoice} />

      <div className="px-4 pt-4 max-w-4xl mx-auto">
        <OrderDetailSummary
          customerName={data?.customer_details.name ?? ""}
          agentName={data?.agent_details.username ?? ""}
          orderDate={data?.created_at?.slice(0, 10) ?? ""}
          status={data?.status ?? ""}
        />
        <OrderDetailItems items={data?.items} />
      </div>
    </div>
  );
}
