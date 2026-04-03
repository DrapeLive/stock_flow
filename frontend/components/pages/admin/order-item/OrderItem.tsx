"use client";
import { PageLoading } from "@/components/ui/Loading";
import { orderApi } from "@/lib/api/order";
import { toastError } from "@/lib/toast";
import { OrderItems } from "@/types/order";
import { Trash, CheckCircle2, Circle } from "lucide-react";
import Image from "next/image";
import { useState, useEffect } from "react";
import { ImagePreview } from "@/components/pages/ImagePreview";

type Props = {
  items: OrderItems | undefined;
  isDelete?: boolean;
  orderId?: number;
  isPacking?: boolean;
  onPackedChange?: () => void;
};

const OrderItem: React.FC<Props> = ({
  items,
  isDelete,
  orderId,
  isPacking,
  onPackedChange,
}) => {
  const [loading, setLoading] = useState(false);
  const [orderItems, setOrderItems] = useState(items);

  useEffect(() => {
    setOrderItems(items);
  }, [items]);

  const onDelete = async (itemId: number, orderId?: number) => {
    if (!orderId) return;
    try {
      setLoading(true);
      await orderApi.deleteItem(orderId, itemId);
      setOrderItems((prev) => prev?.filter((item) => item.id !== itemId));
    } catch (err) {
      toastError("Failed to delete item", err);
    } finally {
      setLoading(false);
    }
  };

  const togglePacked = async (
    itemId: number,
    currentPacked: number,
    totalQuantity: number,
  ) => {
    try {
      const newPacked = currentPacked >= totalQuantity ? 0 : totalQuantity;
      await orderApi.updateItem(itemId, { packed_quantity: newPacked });

      setOrderItems((prev) =>
        prev?.map((item) =>
          item.id === itemId ? { ...item, packed_quantity: newPacked } : item,
        ),
      );
      if (onPackedChange) onPackedChange();
    } catch (err) {
      console.error("Error updating packed status:", err);
      toastError("Failed to update packed status", err);
    }
  };

  if (loading) return <PageLoading />;

  return (
    <div className="pt-3 space-y-3">
      {orderItems?.map((item, index) => {
        const isFullyPacked = (item.packed_quantity ?? 0) >= item.quantity;
        const itemImage = item.item.variants.find(
          (v) => v.id === item.variant,
        )?.image;

        return (
          <div
            className={`flex w-full border-b border-gray-50 py-4 px-2 transition-all duration-300 ${isFullyPacked ? "bg-green-50/40 opacity-80" : "bg-white hover:bg-gray-50/50"}`}
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

            {isPacking && (
              <button
                type="button"
                onClick={() =>
                  togglePacked(
                    item.id,
                    item.packed_quantity ?? 0,
                    item.quantity,
                  )
                }
                className="flex justify-center items-center p-2 mr-1"
                title={isFullyPacked ? "Mark as unpacked" : "Mark as packed"}
              >
                {isFullyPacked ? (
                  <CheckCircle2 className="text-green-600 w-6 h-6" />
                ) : (
                  <Circle className="text-gray-300 w-6 h-6 hover:text-primary/50 transition-colors" />
                )}
              </button>
            )}

            <div
              className={`flex flex-1 justify-between ${isFullyPacked ? "opacity-60" : ""}`}
            >
              <div className="flex">
                <div className="relative w-[50px] h-[50px] flex-shrink-0">
                  {itemImage ? (
                    isDelete || isPacking ? (
                      <Image
                        src={itemImage}
                        fill
                        alt={item.item.name}
                        className="rounded-md object-cover border border-gray-100"
                        unoptimized
                      />
                    ) : (
                      <ImagePreview src={itemImage} alt={item.item.name} />
                    )
                  ) : (
                    <div className="w-full h-full bg-gray-100 rounded-md border border-gray-100" />
                  )}
                </div>
                <div className="pl-3 flex flex-col justify-center">
                  <h6
                    className={`font-semibold text-sm ${isFullyPacked ? "line-through text-gray-400" : "text-gray-900"}`}
                  >
                    {item.item.name}
                  </h6>
                </div>
              </div>

              <div className="flex items-center gap-6 pr-2">
                <div className="bg-gray-50 px-2 py-1 rounded text-xs font-bold text-gray-600 border border-gray-100 min-w-[32px] text-center">
                  {item.size_group}
                </div>
                <div className="flex flex-col items-end min-w-[60px]">
                  <h3 className="text-lg font-bold leading-none">
                    {item.quantity}
                  </h3>
                  <p className="text-[10px] text-gray-400 uppercase font-medium">
                    Pieces
                  </p>
                </div>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
};

export default OrderItem;
