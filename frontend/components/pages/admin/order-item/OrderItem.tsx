"use client";
import { PageLoading } from "@/components/ui/Loading";
import { orderApi } from "@/lib/api/order";
import { toastError, toastSuccess } from "@/lib/toast";
import { OrderItems } from "@/types/order";
import { useState, useEffect } from "react";

import { OrderItemRow } from "@/components/order";

type Props = {
  items: OrderItems | undefined;
  isDeletable?: boolean;
  orderId?: number;
  isPacking?: boolean;
  isDispatching?: boolean;
  onPackedChange?: () => void;
  onDeleteItem?: (itemId: number) => void;
  status?: string;
};

const OrderItem: React.FC<Props> = ({
  items,
  isDeletable,
  orderId,
  isPacking,
  isDispatching,
  onPackedChange,
  onDeleteItem,
  status,
}) => {
  const [loading, setLoading] = useState(false);
  const [orderItems, setOrderItems] = useState(items);
  const [showUnpackDialog, setShowUnpackDialog] = useState(false);
  const [pendingUnpack, setPendingUnpack] = useState<{
    itemId: number;
    newPacked: number;
  } | null>(null);

  useEffect(() => {
    setOrderItems(items);
  }, [items]);

  const handleTogglePacked = async () => {
    if (!pendingUnpack) return;
    const { itemId, newPacked } = pendingUnpack;

    try {
      setLoading(true);
      await orderApi.updateItem(itemId, { packed_quantity: newPacked });

      if (status === "PACKED" && orderId) {
        await orderApi.update(orderId, { status: "PENDING" });
        toastSuccess("Order status changed to PENDING");
      }

      setOrderItems((prev) =>
        prev?.map((item) =>
          item.id === itemId ? { ...item, packed_quantity: newPacked } : item,
        ),
      );
      if (onPackedChange) onPackedChange();
    } catch (err) {
      console.error("Error updating packed status:", err);
      toastError("Failed to update packed status");
    } finally {
      setLoading(false);
      setShowUnpackDialog(false);
      setPendingUnpack(null);
    }
  };

  const togglePacked = async (
    itemId: number,
    currentPacked: number,
    totalPieces: number,
  ) => {
    const newPacked = currentPacked >= totalPieces ? 0 : totalPieces;

    if (status === "PACKED" && newPacked < currentPacked) {
      setPendingUnpack({ itemId, newPacked });
      setShowUnpackDialog(true);
      return;
    }

    try {
      const updatePromise = orderApi.updateItem(itemId, {
        packed_quantity: newPacked,
      });
      const statusPromise =
        status === "PACKED" && orderId
          ? orderApi.update(orderId, { status: "PENDING" })
          : Promise.resolve();

      setLoading(true);
      await Promise.all([updatePromise, statusPromise]);

      if (status === "PACKED" && orderId) {
        toastSuccess("Order status changed to PENDING");
      }

      setOrderItems((prev) =>
        prev?.map((item) =>
          item.id === itemId ? { ...item, packed_quantity: newPacked } : item,
        ),
      );
      if (onPackedChange) onPackedChange();
    } catch (err) {
      console.error("Error updating packed status:", err);
      toastError("Failed to update packed status");
    } finally {
      setLoading(false);
    }
  };

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

  if (loading) return <PageLoading />;

  return (
    <>
      <div className="pt-3 space-y-1">
        {orderItems
          ?.filter((item) => {
            if (!isDispatching) return true;
            const totalPieces = (item.piece_count || 1) * item.quantity;
            const isFullyPacked = (item.packed_quantity ?? 0) >= totalPieces;
            return isFullyPacked;
          })
          .map((item) => {
            const totalPieces = (item.piece_count || 1) * item.quantity;
            const isFullyPacked = (item.packed_quantity ?? 0) >= totalPieces;

            return (
              <OrderItemRow
                key={item.id}
                item={item}
                showDelete={isDeletable}
                showPackedToggle={isPacking}
                isPacked={isFullyPacked}
                onDelete={() => onDeleteItem?.(item.id)}
                onTogglePacked={(id, packed) => {
                  const newPacked = packed ? totalPieces : 0;
                  togglePacked(id, item.packed_quantity ?? 0, totalPieces);
                }}
              />
            );
          })}
      </div>

      {showUnpackDialog && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl p-6 max-w-sm w-full shadow-xl">
            <h3 className="text-lg font-bold text-gray-900 mb-2">
              Unpack Items?
            </h3>
            <p className="text-sm text-gray-500 mb-6">
              Order is currently marked as packed. Unpacking items will change
              the order status back to PENDING. Continue?
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => {
                  setShowUnpackDialog(false);
                  setPendingUnpack(null);
                }}
                className="flex-1 py-3 px-4 rounded-xl border border-gray-200 text-gray-700 font-medium hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleTogglePacked}
                className="flex-1 py-3 px-4 rounded-xl bg-primary text-white font-medium hover:bg-primary/90 transition-colors"
              >
                Unpack
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
};

export default OrderItem;
