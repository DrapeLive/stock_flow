"use client";
import OrderItem from "@/components/pages/admin/order-item/OrderItem";
import { customerApi } from "@/lib/api/customer";
import { CustomerResponse } from "@/types/customer";
import { ChevronLeft, Plus } from "lucide-react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { orderApi } from "@/lib/api/order";
import { OrderResponse } from "@/types/order";
import { PageLoading } from "@/components/ui/Loading";
import { FailedBox } from "@/components/ui/FailBox";

export default function Page() {
  const params = useParams();
  const id = params.id as string;

  const router = useRouter();

  const [data, setData] = useState<CustomerResponse>();
  const [loading, setLoading] = useState(true);
  const [orders, setOrders] = useState<OrderResponse>();
  const [error, setError] = useState(false);

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await customerApi.getOne(id);
        setData(response);
        const key = localStorage.getItem("orderKey");
        if (key) {
          const res2 = await orderApi.getOne(Number(key));
          setOrders(res2);
        }
      } catch {
        setError(true);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  if (error)
    return (
      <FailedBox
        title="Failed"
        description="Server Error"
        onClose={() => router.push(`/order/new/`)}
      />
    );

  if (loading) return <PageLoading />;

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
        <OrderItem orderId={orders?.id} items={orders?.items} isDelete={true} />
      )}
    </div>
  );
}
