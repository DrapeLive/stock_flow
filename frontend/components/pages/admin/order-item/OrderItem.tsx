"use client";
import { AlertDestructive } from "@/components/ui/AlertDestructive";
import { PageLoading } from "@/components/ui/Loading";
import { orderApi } from "@/lib/api/order";
import { OrderItems } from "@/types/order";
import { Trash } from "lucide-react";
import Image from "next/image";
import { useState } from "react";

type Props = {
  items: OrderItems | undefined;
  isDelete?: boolean;
  orderId?: number;
};

const OrderItem: React.FC<Props> = ({ items, isDelete, orderId }) => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [orderItems, setOrderItems] = useState(items);

  const onDelete = async (itemId: number, orderId?: number) => {
    try {
      setLoading(true);
      await orderApi.deleteItem(String(orderId), String(itemId));

      setOrderItems((prev) => prev?.filter((item) => item.id !== itemId));
    } catch {
      setError("Server Not Found");
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <PageLoading />;

  return (
    <div className="pt-3 space-y-3">
      {error && <AlertDestructive heading="Error" description={error} />}
      {orderItems?.map((item, index) => (
        <div
          className="flex w-full border-b border-(--color-border) py-2"
          key={index}
        >
          {isDelete && (
            <button
              type="button"
              onClick={() => onDelete(item.id, orderId)}
              className="flex justify-center items-center p-2"
            >
              <Trash className="text-red-600 w-4 h-4" />
            </button>
          )}
          <div className="flex justify-between">
            <Image
              src={item.variant.image!}
              width={45}
              height={45}
              alt=""
              unoptimized
            />
            <div className="pl-4 min-w-40">
              <h6>{item.item.name}</h6>
              <p>{item.variant.color}</p>
            </div>
          </div>
          <div className="ml-6 flex justify-around w-full">
            <div className="flex items-center ">
              <h6>{item.size.size}</h6>
            </div>
            <div className="flex flex-col justify-center items-center">
              <h3>{item.quantity}</h3>
              <p>Pieces</p>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
};

export default OrderItem;
