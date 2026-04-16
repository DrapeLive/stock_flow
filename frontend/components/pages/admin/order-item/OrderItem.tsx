"use client";
import { PageLoading } from "@/components/ui/Loading";
import { orderApi } from "@/lib/api/order";
import { toastError } from "@/lib/toast";
import { OrderItems } from "@/types/order";
import { useState, useEffect } from "react";

import { OrderItemRow } from "@/components/order";

type Props = {
  items: OrderItems | undefined;
  isDelete?: boolean;
  orderId?: number;
  isPacking?: boolean;
  onPackedChange?: () => void;
  onDeleteItem?: (itemId: number) => void;
};

const OrderItem: React.FC<Props> = ({
  items,
  isDelete,
  orderId,
  isPacking,
  onPackedChange,
  onDeleteItem,
}) => {
  const [loading, setLoading] = useState(false);
  const [orderItems, setOrderItems] = useState(items);

  useEffect(() => {
    setOrderItems(items);
  }, [items]);

  const onDelete = async (itemId: number, orderId?: number) => {
    if (onDeleteItem) {
      onDeleteItem(itemId);
      return;
    }
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
    totalPieces: number,
  ) => {
    try {
      const newPacked = currentPacked >= totalPieces ? 0 : totalPieces;
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
    <div className="pt-3 space-y-1">
      {orderItems?.map((item) => {
        const totalPieces = (item.piece_count || 1) * item.quantity;
        const isFullyPacked = (item.packed_quantity ?? 0) >= totalPieces;

        return (
          <OrderItemRow
            key={item.id}
            item={item}
            showDelete={isDelete}
            showPackedToggle={isPacking}
            isPacked={isFullyPacked}
            onDelete={() => onDelete(item.id, orderId)}
            onTogglePacked={(id, packed) => {
              const newPacked = packed ? totalPieces : 0;
              togglePacked(id, item.packed_quantity ?? 0, totalPieces);
            }}
          />
        );
      })}
    </div>
  );
};

export default OrderItem;
