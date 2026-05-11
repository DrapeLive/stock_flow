"use client";
import { useState } from "react";
import { CheckCircle2, PackageCheck } from "lucide-react";
import { OrderItem as OrderItemType } from "@/types/order";
import OrderItem from "@/components/pages/admin/order-item/OrderItem";
import { toastSuccess, toastError } from "@/lib/toast";
import { orderApi } from "@/lib/api/order";

interface OrderItemsSectionProps {
  items?: OrderItemType[];
  activeTab: string;
  isPackingMode: boolean;
  onPackedChange: () => void;
  onTogglePackingMode: () => void;
  status?: string;
  orderId?: number;
}

export default function OrderItemsSection({
  items,
  activeTab,
  isPackingMode,
  onPackedChange,
  onTogglePackingMode,
  status,
  orderId,
}: OrderItemsSectionProps) {
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
  const [itemToDelete, setItemToDelete] = useState<number | null>(null);
  const [deleting, setDeleting] = useState(false);

  const handleDeleteClick = (itemId: number) => {
    setItemToDelete(itemId);
    setShowDeleteDialog(true);
  };

  const confirmDelete = async () => {
    if (!itemToDelete || !orderId) return;
    setDeleting(true);
    try {
      await orderApi.deleteItem(orderId, itemToDelete);
      toastSuccess("Item deleted successfully");
      setShowDeleteDialog(false);
      setItemToDelete(null);
      onPackedChange();
    } catch (err) {
      toastError("Failed to delete item");
      console.error(err);
    } finally {
      setDeleting(false);
    }
  };

  const isEditable =
    status === "DRAFT" || status === "PENDING" || status === "PACKED";

  return (
    <>
      <div className="flex justify-between items-end mb-4 border-b border-gray-100 pb-2">
        <div>
          <h2 className="text-lg font-extrabold text-gray-900 leading-tight">
            Items to {activeTab}
          </h2>
          <p className="text-xs text-gray-400 font-medium">
            Manage order items below
          </p>
        </div>

        {activeTab === "Packing" && status !== "DISPATCHED" && (
          <button
            onClick={onTogglePackingMode}
            className={`px-4 py-2 rounded-md flex gap-2 items-center font-bold text-sm transition-all ${
              isPackingMode
                ? "bg-green-600 text-white shadow-lg"
                : "bg-primary text-white shadow-md"
            }`}
          >
            {isPackingMode ? (
              <>
                <CheckCircle2 size={18} />
                <span>Done Selecting</span>
              </>
            ) : (
              <>
                <PackageCheck size={18} />
                <span>Update Packing</span>
              </>
            )}
          </button>
        )}
      </div>

      <div className="bg-white rounded-2xl overflow-hidden">
        <OrderItem
          items={items}
          isPacking={isPackingMode && activeTab === "Packing"}
          isDispatching={activeTab === "Dispatching"}
          onPackedChange={onPackedChange}
          isDeletable={isEditable}
          orderId={orderId}
          onDeleteItem={handleDeleteClick}
          status={status}
        />
      </div>

      {showDeleteDialog && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl p-6 max-w-sm w-full shadow-xl">
            <h3 className="text-lg font-bold text-gray-900 mb-2">
              Delete Item?
            </h3>
            <p className="text-sm text-gray-500 mb-6">
              {status !== "DRAFT"
                ? "This will return the stock back to the warehouse. This action cannot be undone."
                : "Are you sure you want to remove this item from the order?"}
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setShowDeleteDialog(false)}
                className="flex-1 py-3 px-4 rounded-xl border border-gray-200 text-gray-700 font-medium hover:bg-gray-50 transition-colors"
                disabled={deleting}
              >
                Cancel
              </button>
              <button
                onClick={confirmDelete}
                disabled={deleting}
                className="flex-1 py-3 px-4 rounded-xl bg-red-500 text-white font-medium hover:bg-red-600 transition-colors disabled:opacity-50"
              >
                {deleting ? "Deleting..." : "Delete"}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
