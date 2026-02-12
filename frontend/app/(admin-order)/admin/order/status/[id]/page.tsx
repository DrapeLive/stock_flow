"use client";
import { ChevronLeft, Plus } from "lucide-react";
import Link from "next/link";
import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { orderApi } from "@/lib/api/order";
import { OrderResponse } from "@/types/order";
import OrderItem from "@/components/pages/admin/order-item/OrderItem";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { Truck } from "lucide-react";

type Tab = "Packing" | "Dispatching";

export default function Page() {
  const params = useParams();
  const id = params.id as string;

  const router = useRouter();

  const [activeTab, setActiveTab] = useState<Tab>("Packing");
  const [loading, setLoading] = useState(false);
  const [data, setData] = useState<OrderResponse>();

  useEffect(() => {
    setLoading(true);

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

  if (loading) return <h2 className="flex justify-center">Loading</h2>;

  return (
    <div className="min-h-screen min-w-full">
      <div className="w-full">
        <Link
          className="flex text-(--color-primary) items-center"
          href={"/admin/"}
        >
          <ChevronLeft size={18} />
          <h5>Back</h5>
        </Link>
      </div>
      <div className="border p-1 mt-2 flex items-center justify-center space-x-1 border-(--color-border) rounded-full">
        <button
          onClick={() => setActiveTab("Packing")}
          className={`rounded-full px-12 py-1 font-semibold text-xs ${activeTab == "Packing" ? "bg-(--color-primary) text-white" : "bg-white text-black"}`}
        >
          Packing
        </button>
        <button
          onClick={() => setActiveTab("Dispatching")}
          className={`rounded-full px-12 py-1 font-semibold text-xs ${activeTab == "Dispatching" ? "bg-(--color-primary) text-white" : "bg-white text-black"}`}
        >
          Dispatching
        </button>
      </div>
      <h2 className="mt-2 font-medium">Order Details</h2>
      <div className="space-y-2">
        <h3>
          <span className="text-(--color-text)">Customer: </span>
          {data?.customer_details.name}
        </h3>
        <h3>
          <span className="text-(--color-text)">Agent: </span>
          {data?.agent_details.username}
        </h3>
        <h3>
          <span className="text-(--color-text)">Order Date: </span>
          {data?.created_at?.slice(0, 10)}
        </h3>
        <div className="flex">
          <h3 className="text-(--color-text)">Current status: </h3>
          <div className="ml-2 rounded-full bg-(--color-pending)/20 border border-(--color-pending) px-3 py-0.5">
            <p className="text-(--color-pending)">{data?.status}</p>
          </div>
        </div>
      </div>
      <div className="pt-4 flex justify-between">
        <div className="text-[20px]">Package Status</div>
        {activeTab == "Packing" && (
          <button
            onClick={() => router.push(`/admin/order/status/${id}/edit`)}
            className="p-2 bg-(--color-primary) flex gap-1 items-center text-white rounded-md"
          >
            <h5>Edit</h5>
            <Plus size={18} />
          </button>
        )}
      </div>
      <OrderItem items={data?.items} />

      <div className="w-full pt-8 flex justify-center">
        {activeTab == "Dispatching" && (
          <StockFlowButton text="Disptach" icon={<Truck />} />
        )}
      </div>
    </div>
  );
}
