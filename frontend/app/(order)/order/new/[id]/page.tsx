"use client";
import OrderItem from "@/components/pages/admin/order-item/OrderItem";
import { customerApi } from "@/lib/api/customer";
import { CustomerResponse } from "@/types/customer";
import { ChevronLeft, Plus } from "lucide-react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { agentApi } from "@/lib/api/agents";
import { useAuth } from "@/context/AuthContext";
import { orderApi } from "@/lib/api/order";
import { OrderResponse } from "@/types/order";

export default function Page() {
  const { user } = useAuth();
  const params = useParams();
  const id = params.id as string;

  const router = useRouter();

  const [data, setData] = useState<CustomerResponse>();
  const [loading, setLoading] = useState(true);
  const [agentId, setAgentId] = useState(0);
  const [orders, setOrders] = useState<OrderResponse>();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await customerApi.getOne(id);
        setData(response);
        const res = await agentApi.getOne(user?.id);
        setAgentId(res.user.id);
        const res1 = await orderApi.create({
          agent: agentId,
          customer: Number(data?.id),
          status: "PENDING",
        });
        if (res1) {
          console.log("Create Order");
        }
        const res2 = await orderApi.getOne(res1.id);
        setOrders(res2);
      } catch (error) {
        console.error("Error fetching data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  if (loading) return <h2>Loading</h2>;

  return (
    <div className="min-h-screen min-w-full">
      <div className="w-full">
        <Link
          className="flex text-(--color-primary) items-center"
          href={"/order/new"}
        >
          <ChevronLeft size={18} />
          <h5>Back</h5>
        </Link>
      </div>
      <h2 className="mt-5">New Order</h2>
      <h3>
        <span className="text-(--color-text)">Customer: </span>
        {data?.name}
      </h3>
      <div className="pt-4 flex justify-between">
        <div className="text-[20px]">Items</div>
        <button
          onClick={() => router.push(`/order/new/${id}/scanner`)}
          className="p-2 bg-(--color-primary) flex gap-1 items-center text-white rounded-md"
        >
          <h5>Add</h5>
          <Plus size={18} />
        </button>
      </div>
      {orders?.items.length == 0 ? (
        <h2>Add Items</h2>
      ) : (
        <OrderItem items={orders?.items} />
      )}
    </div>
  );
}
