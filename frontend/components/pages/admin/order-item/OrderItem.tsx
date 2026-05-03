"use client";
import { PageLoading } from "@/components/ui/Loading";
import { orderApi } from "@/lib/api/order";
import { itemApi } from "@/lib/api/item";
import { toastError, toastSuccess } from "@/lib/toast";
import { OrderItem as OrderItemType, OrderItems } from "@/types/order";
import { VariantAllItem, VariantSize, ItemType } from "@/types/item";
import {
  SIZE_RANGE_TO_SIZES,
  SIZE_RANGE_PIECE_COUNT,
  FrontendSizeRange,
  getSizesForItemType,
} from "@/types/item";
import { useState, useEffect } from "react";

import { OrderItemRow } from "@/components/order";

function getAvailableStockForSizeGroup(
  variantSizes: VariantSize[],
  sizeGroup: string,
  reservedItems: Array<{ size_group: string; quantity: number }>,
): number {
  const selectedSizes =
    SIZE_RANGE_TO_SIZES[sizeGroup as FrontendSizeRange] || [];
  if (selectedSizes.length === 0) return 0;

  const remainingStocks = selectedSizes.map((selectedSize) => {
    const baseStock =
      variantSizes.find((s) => s.size === selectedSize)?.stock || 0;

    const reservedForThisSize = reservedItems.reduce((sum, item) => {
      const itemSizes =
        SIZE_RANGE_TO_SIZES[item.size_group as FrontendSizeRange] || [];
      if (itemSizes.includes(selectedSize)) {
        return sum + item.quantity;
      }
      return sum;
    }, 0);

    return baseStock - reservedForThisSize;
  });

  return Math.max(0, Math.min(...remainingStocks));
}

function getPiecesForGroup(sizeGroup: string): number {
  return SIZE_RANGE_PIECE_COUNT[sizeGroup] || 0;
}

function getAvailableSizeGroups(
  variantSizes: VariantSize[],
  itemType: ItemType,
): string[] {
  const variantSizeSet = new Set(variantSizes.map((s) => s.size));
  return getSizesForItemType(itemType, "order_creation").filter((range) => {
    const requiredSizes = SIZE_RANGE_TO_SIZES[range];
    return requiredSizes.every((s) => variantSizeSet.has(s));
  });
}

type Props = {
  items: OrderItems | undefined;
  isDeletable?: boolean;
  isEditable?: boolean;
  orderId?: number;
  isPacking?: boolean;
  isDispatching?: boolean;
  onPackedChange?: () => void;
  onDeleteItem?: (itemId: number) => void;
  status?: string;
  outOfStockItemIds?: number[];
};

const OrderItem: React.FC<Props> = ({
  items,
  isDeletable,
  isEditable,
  orderId,
  isPacking,
  isDispatching,
  onPackedChange,
  onDeleteItem,
  status,
  outOfStockItemIds = [],
}) => {
  const [loading, setLoading] = useState(false);
  const [orderItems, setOrderItems] = useState(items);
  const [showUnpackDialog, setShowUnpackDialog] = useState(false);
  const [pendingUnpack, setPendingUnpack] = useState<{
    itemId: number;
    newPacked: number;
  } | null>(null);
  const [editingItem, setEditingItem] = useState<OrderItemType | null>(null);
  const [editQuantity, setEditQuantity] = useState(1);
  const [editSizeGroup, setEditSizeGroup] = useState("");
  const [editPieceCount, setEditPieceCount] = useState(1);
  const [editPackedQty, setEditPackedQty] = useState(0);
  const [showEditDialog, setShowEditDialog] = useState(false);
  const [availableVariants, setAvailableVariants] = useState<VariantAllItem[]>(
    [],
  );
  const [sizeGroupOptions, setSizeGroupOptions] = useState<string[]>([]);
  const [variantSizes, setVariantSizes] = useState<VariantSize[]>([]);
  const [variantsLoading, setVariantsLoading] = useState(false);
  const [sizeGroupError, setSizeGroupError] = useState<string | null>(null);
  const [quantityError, setQuantityError] = useState<string | null>(null);

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
      await orderApi.deleteItem(orderId!, itemId);
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

  const handleEditItem = async (item: OrderItemType) => {
    setEditingItem(item);
    setEditQuantity(item.quantity);
    setEditSizeGroup(item.size_group || "");
    setEditPieceCount(item.piece_count || 1);
    setEditPackedQty(item.packed_quantity || 0);
    setShowEditDialog(true);
    setSizeGroupError(null);
    setQuantityError(null);
    setVariantsLoading(true);

    try {
      const variants = await itemApi.getAllVariants();
      setAvailableVariants(variants);

      const variantId = item.variant;
      const variant = variants.find((v) => v.id === variantId);
      const itemType = item.item_type as ItemType | undefined;
      if (variant && itemType) {
        const validItemType =
          itemType === "kids" || itemType === "gents" ? itemType : "gents";
        const availableGroups = getAvailableSizeGroups(
          variant.sizes || [],
          validItemType,
        );
        setSizeGroupOptions(availableGroups);
        setVariantSizes(variant.sizes || []);

        const pieceCount = getPiecesForGroup(item.size_group || "");
        setEditPieceCount(pieceCount > 0 ? pieceCount : item.piece_count || 1);

        if (availableGroups.length === 0) {
          setSizeGroupError("No sizes available for this variant");
        } else if (!availableGroups.includes(item.size_group || "")) {
          setSizeGroupError("Current size group is no longer available");
        }
      }
    } catch (err) {
      console.error("Error fetching variants:", err);
    } finally {
      setVariantsLoading(false);
    }
  };

  const saveEditItem = async () => {
    if (!editingItem || !orderId) return;
    if (editQuantity < 1) {
      toastError("Quantity must be at least 1");
      return;
    }
    if (!editSizeGroup) {
      toastError("Please select a size group");
      return;
    }

    const reservedItems =
      orderItems
        ?.filter((item) => item.id !== editingItem.id)
        .map((item) => ({
          size_group: item.size_group || "",
          quantity: item.quantity,
        })) || [];

    const maxAvailable = getAvailableStockForSizeGroup(
      variantSizes,
      editSizeGroup,
      reservedItems,
    );
    if (editQuantity > maxAvailable) {
      setQuantityError(
        `Only ${maxAvailable} sets available for this size group`,
      );
      return;
    }

    try {
      setLoading(true);
      const newPackedQty = Math.min(
        editPackedQty,
        editQuantity * editPieceCount,
      );
      await orderApi.updateItem(editingItem.id, {
        quantity: editQuantity,
        size_group: editSizeGroup,
        packed_quantity: newPackedQty,
      });
      setOrderItems((prev) =>
        prev?.map((item) =>
          item.id === editingItem.id
            ? {
                ...item,
                quantity: editQuantity,
                size_group: editSizeGroup,
                packed_quantity: newPackedQty,
                piece_count: editPieceCount,
              }
            : item,
        ),
      );
      toastSuccess("Item updated successfully");
    } catch (err: any) {
      console.error("Error updating item:", err);
      toastError(err.response?.data?.error || "Failed to update item");
    } finally {
      setLoading(false);
      setShowEditDialog(false);
      setEditingItem(null);
    }
  };

  if (loading) return <PageLoading />;

  return (
    <>
      <div className="pt-0 space-y-1">
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
                showEdit={isEditable}
                showPackedToggle={isPacking}
                isPacked={isFullyPacked}
                isOutOfStock={outOfStockItemIds.includes(item.id)}
                onDelete={(deleteItemID) => onDelete(deleteItemID, orderId)}
                onEdit={isEditable ? handleEditItem : undefined}
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

      {showEditDialog && editingItem && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl p-6 max-w-sm w-full shadow-xl max-h-[90vh] overflow-y-auto">
            <h3 className="text-lg font-bold text-gray-900 mb-1">Edit Item</h3>
            <p className="text-sm text-gray-500 mb-4">
              {editingItem.item_name}
            </p>

            {variantsLoading ? (
              <div className="flex items-center justify-center py-8">
                <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary"></div>
              </div>
            ) : sizeGroupOptions.length === 0 ? (
              <div className="py-6 text-center">
                <p className="text-sm text-red-500 font-medium">
                  No sizes available
                </p>
                <button
                  onClick={() => {
                    setShowEditDialog(false);
                    setEditingItem(null);
                  }}
                  className="mt-4 w-full py-3 px-4 rounded-xl border border-gray-200 text-gray-700 font-medium hover:bg-gray-50 transition-colors"
                >
                  Close
                </button>
              </div>
            ) : (
              <>
                <div className="mb-4">
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider">
                    Size Group
                  </label>
                  <select
                    value={editSizeGroup}
                    onChange={(e) => {
                      const newGroup = e.target.value;
                      setEditSizeGroup(newGroup);
                      setSizeGroupError(null);
                      setQuantityError(null);
                      if (newGroup) {
                        setEditPieceCount(getPiecesForGroup(newGroup));
                      }
                    }}
                    className={`w-full mt-1 px-4 py-3 rounded-xl border text-lg font-bold focus:outline-none focus:ring-2 focus:ring-primary/50 bg-white ${
                      sizeGroupError ? "border-red-300" : "border-gray-200"
                    }`}
                  >
                    <option value="">Select Size Group</option>
                    {sizeGroupOptions.map((group) => (
                      <option key={group} value={group}>
                        {group}
                      </option>
                    ))}
                  </select>
                  {sizeGroupError && (
                    <p className="text-xs text-red-500 mt-1">
                      {sizeGroupError}
                    </p>
                  )}
                  {editSizeGroup &&
                    !sizeGroupError &&
                    variantSizes.length > 0 &&
                    (() => {
                      const reservedItems =
                        orderItems
                          ?.filter((item) => item.id !== editingItem.id)
                          .map((item) => ({
                            size_group: item.size_group || "",
                            quantity: item.quantity,
                          })) || [];
                      const available = getAvailableStockForSizeGroup(
                        variantSizes,
                        editSizeGroup,
                        reservedItems,
                      );
                      return (
                        <div className="flex w-full justify-between mt-1">
                          <p className="text-xs text-gray-500">
                            Available: {available} sets
                          </p>
                          <p className="text-xs text-gray-500">
                            {editPieceCount} pcs/set
                          </p>
                        </div>
                      );
                    })()}
                </div>

                <div className="mb-4">
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider">
                    Quantity (sets)
                  </label>
                  <input
                    type="number"
                    min="1"
                    value={editQuantity}
                    onChange={(e) => {
                      setEditQuantity(
                        Math.max(1, parseInt(e.target.value) || 1),
                      );
                      setQuantityError(null);
                    }}
                    className={`w-full mt-1 px-4 py-3 rounded-xl border text-lg font-bold focus:outline-none focus:ring-2 focus:ring-primary/50 ${
                      quantityError ? "border-red-300" : "border-gray-200"
                    }`}
                  />
                  {quantityError && (
                    <p className="text-xs text-red-500 mt-1">{quantityError}</p>
                  )}
                  {editSizeGroup &&
                    !quantityError &&
                    variantSizes.length > 0 &&
                    (() => {
                      const reservedItems =
                        orderItems
                          ?.filter((item) => item.id !== editingItem.id)
                          .map((item) => ({
                            size_group: item.size_group || "",
                            quantity: item.quantity,
                          })) || [];
                      const available = getAvailableStockForSizeGroup(
                        variantSizes,
                        editSizeGroup,
                        reservedItems,
                      );
                      return (
                        <p className="text-xs text-gray-500 mt-1">
                          Max available: {available} sets
                        </p>
                      );
                    })()}
                </div>

                <div className="flex gap-3">
                  <button
                    onClick={() => {
                      setShowEditDialog(false);
                      setEditingItem(null);
                    }}
                    className="flex-1 py-3 px-4 rounded-xl border border-gray-200 text-gray-700 font-medium hover:bg-gray-50 transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={saveEditItem}
                    disabled={
                      !!sizeGroupError ||
                      !!quantityError ||
                      !editSizeGroup ||
                      !editQuantity ||
                      variantsLoading
                    }
                    className={`flex-1 py-3 px-4 rounded-xl font-medium transition-colors ${
                      sizeGroupError ||
                      quantityError ||
                      !editSizeGroup ||
                      !editQuantity ||
                      variantsLoading
                        ? "bg-gray-300 text-gray-500 cursor-not-allowed"
                        : "bg-primary text-white hover:bg-primary/90"
                    }`}
                  >
                    Save
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </>
  );
};

export default OrderItem;
