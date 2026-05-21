"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { Info } from "lucide-react";
import { itemApi } from "@/lib/api/item";
import { orderApi } from "@/lib/api/order";
import { PageLoading } from "@/components/ui/Loading";
import { toastSuccess, toastError } from "@/lib/toast";
import type { ItemQRResponse, ItemVariant } from "@/types/item";

import { getAvailableSizeRanges, getAvailableStockForSizeGroup } from "./utils";

import ProductHeader from "./components/ProductHeader";
import ProductImage from "./components/ProductImage";
import ProductInfo from "./components/ProductInfo";
import VariantSelector from "./components/VariantSelector";
import SizeGroupSelector from "./components/SizeGroupSelector";
import QuantitySelector from "./components/QuantitySelector";
import SubmitButton from "./components/SubmitButton";
import { useBackButton } from "@/util/useBackButton";

export default function ProductDetailPage() {
    const params = useParams<{ id: string; qr: string }>();
    const id = params.id as string;
    const router = useRouter();

    const [data, setData] = useState<ItemQRResponse | null>(null);
    const [quantity, setQuantity] = useState<number>(1);
    const [selectedVariant, setSelectedVariant] = useState<ItemVariant | null>(
        null,
    );
    const [selectedSizeGroup, setSelectedSizeGroup] = useState<string | null>(
        null,
    );
    const [loading, setLoading] = useState(false);
    const [validationError, setValidationError] = useState<string | null>(null);
    const [existingOrderItems, setExistingOrderItems] = useState<
        Array<{
            id: number;
            variant_id: number;
            size_group: string;
            quantity: number;
        }>
    >([]);
    const [isEditMode, setIsEditMode] = useState(false);
    const [editingItemId, setEditingItemId] = useState<number | null>(null);

    useBackButton({
        onBack: useCallback(() => {
            router.push(`/agent/order/new/${id}`);
        }, [router, id]),
    });

    useEffect(() => {
        setLoading(true);
        const fetchData = async () => {
            try {
                const [itemResponse, orderResponse] = await Promise.all([
                    itemApi.byqr(params.qr),
                    (async () => {
                        const orderKey = localStorage.getItem("orderKey");
                        if (orderKey) {
                            return orderApi.getOne(parseInt(orderKey, 10));
                        }
                        return null;
                    })(),
                ]);

                setData(itemResponse);
                if (itemResponse.variants?.length > 0) {
                    setSelectedVariant(
                        itemResponse.variants.find(
                            (v) =>
                                v.id === (itemResponse.matched_variant_id || 0),
                        ) || itemResponse.variants[0],
                    );
                }

                if (orderResponse) {
                    setExistingOrderItems(
                        orderResponse.items.map((item) => ({
                            id: item.id,
                            variant_id: item.variant || 0,
                            size_group: item.size_group || "",
                            quantity: item.quantity,
                        })),
                    );
                }
            } catch (e) {
                setLoading(false);
                console.error("Error fetching product details:", e);
            } finally {
                setLoading(false);
            }
        };
        fetchData();
    }, [params.qr]);

    const sizeGroups = getAvailableSizeRanges(selectedVariant, data?.type);

    const sizeGroupMeta = useMemo(() => {
        if (!selectedVariant)
            return {} as Record<
                string,
                { stock: number; alreadyAdded: boolean }
            >;

        return Object.fromEntries(
            sizeGroups.map((group) => {
                const reservedItems = existingOrderItems
                    .filter(
                        (item) =>
                            item.variant_id === selectedVariant.id &&
                            (isEditMode ? item.id !== editingItemId : true),
                    )
                    .map((item) => ({
                        size_group: item.size_group,
                        quantity: item.quantity,
                    }));

                const stock = getAvailableStockForSizeGroup(
                    selectedVariant,
                    group,
                    reservedItems,
                );
                const alreadyAdded = existingOrderItems.some(
                    (item) =>
                        item.variant_id === selectedVariant.id &&
                        item.size_group === group &&
                        (isEditMode ? item.id !== editingItemId : true),
                );

                return [group, { stock, alreadyAdded }];
            }),
        );
    }, [
        sizeGroups,
        selectedVariant,
        existingOrderItems,
        isEditMode,
        editingItemId,
    ]);

    const isAlreadyAdded =
        !!selectedSizeGroup &&
        !isEditMode &&
        existingOrderItems.some(
            (item) =>
                item.variant_id === selectedVariant?.id &&
                item.size_group === selectedSizeGroup,
        );

    useEffect(() => {
        if (sizeGroups.length > 0 && !selectedSizeGroup) {
            const bestGroup = sizeGroups.reduce((best, group) => {
                const reservedItems = existingOrderItems
                    .filter((item) => item.variant_id === selectedVariant?.id)
                    .map((item) => ({
                        size_group: item.size_group,
                        quantity: item.quantity,
                    }));
                const stock = getAvailableStockForSizeGroup(
                    selectedVariant,
                    group,
                    reservedItems,
                );
                const bestStock = getAvailableStockForSizeGroup(
                    selectedVariant,
                    best,
                    reservedItems,
                );
                return stock > bestStock ? group : best;
            });
            setSelectedSizeGroup(bestGroup);
        }
    }, [sizeGroups, selectedSizeGroup]);

    const availableStock = (() => {
        if (!selectedVariant || !selectedSizeGroup) return 0;

        const reservedItems = existingOrderItems
            .filter(
                (item) =>
                    item.variant_id === selectedVariant.id &&
                    (isEditMode ? item.id !== editingItemId : true),
            )
            .map((item) => ({
                size_group: item.size_group,
                quantity: item.quantity,
            }));

        return getAvailableStockForSizeGroup(
            selectedVariant,
            selectedSizeGroup,
            reservedItems,
        );
    })();

    useEffect(() => {
        if (quantity > availableStock) {
            setValidationError(
                `Only ${availableStock} items available for selected size group`,
            );
        } else {
            setValidationError(null);
        }
    }, [quantity, availableStock]);

    const handleVariantSelect = (variant: ItemVariant) => {
        const existingForThisVariant = existingOrderItems.find(
            (item) => item.variant_id === variant.id,
        );

        if (
            existingForThisVariant &&
            selectedSizeGroup === existingForThisVariant.size_group &&
            selectedSizeGroup !== null
        ) {
            setIsEditMode(true);
            setEditingItemId(existingForThisVariant.id);
            setQuantity(existingForThisVariant.quantity);
        } else {
            setIsEditMode(false);
            setEditingItemId(null);
            setQuantity(1);
        }
        setSelectedVariant(variant);
        setValidationError(null);
    };

    const handleSizeGroupSelect = (value: string) => {
        const existingForSize = existingOrderItems.find(
            (item) =>
                selectedVariant &&
                item.variant_id === selectedVariant.id &&
                item.size_group === value,
        );
        if (existingForSize && !isEditMode) {
            setIsEditMode(true);
            setEditingItemId(existingForSize.id);
            setQuantity(existingForSize.quantity);
        }
        setSelectedSizeGroup(value);
        setValidationError(null);
    };

    const handleSubmit = async () => {
        if (!selectedVariant) {
            setValidationError("Please select a color/variant");
            return;
        }
        if (!selectedSizeGroup) {
            setValidationError("Please select a size group");
            return;
        }
        if (quantity < 1) {
            setValidationError("Quantity must be at least 1");
            return;
        }

        if (quantity > availableStock) {
            setValidationError(
                `Only ${availableStock} items available for selected size group`,
            );
            return;
        }

        setValidationError(null);

        try {
            setLoading(true);
            const orderKey = localStorage.getItem("orderKey");
            if (orderKey) {
                const orderId = parseInt(orderKey, 10);
                const qrCode = selectedVariant.qr_code;

                const existingSameVariant = existingOrderItems.find(
                    (item) =>
                        item.variant_id === selectedVariant.id &&
                        item.size_group === selectedSizeGroup,
                );

                if (existingSameVariant && !isEditMode) {
                    const newQty = existingSameVariant.quantity + quantity;
                    await orderApi.updateItem(existingSameVariant.id, {
                        quantity: newQty,
                    });
                    setExistingOrderItems((prev) =>
                        prev.map((item) =>
                            item.id === existingSameVariant.id
                                ? { ...item, quantity: newQty }
                                : item,
                        ),
                    );
                    toastSuccess("Quantity Updated");
                } else if (isEditMode && editingItemId) {
                    await orderApi.updateItem(editingItemId, { quantity });
                    setExistingOrderItems((prev) =>
                        prev.map((item) =>
                            item.id === editingItemId
                                ? { ...item, quantity }
                                : item,
                        ),
                    );
                    toastSuccess("Item Updated");
                } else {
                    await orderApi.addItem(orderId, {
                        qr_code: qrCode,
                        quantity,
                        size_group: selectedSizeGroup,
                    });
                    const order = await orderApi.getOne(orderId);
                    const newItem = order.items.find(
                        (i) =>
                            (i.variant || 0) === selectedVariant.id &&
                            (i.size_group || "") === selectedSizeGroup,
                    );
                    if (newItem) {
                        setExistingOrderItems((prev) => [
                            ...prev,
                            {
                                id: newItem.id,
                                variant_id: newItem.variant || 0,
                                size_group: newItem.size_group || "",
                                quantity: newItem.quantity,
                            },
                        ]);
                    }
                    toastSuccess("Item Added Successfully");
                }
                router.push(`/agent/order/new/${id}`);
            } else {
                setLoading(false);
                setValidationError(
                    "Order session not found. Please restart the order.",
                );
            }
        } catch (e) {
            setLoading(false);
            console.error("Error adding item to order:", e);
            toastError("Failed to add item", e);
            router.push(`/agent/order/new/${id}`);
        }
    };

    if (loading) return <PageLoading />;

    return (
        <div className="min-h-screen bg-gray-50/50 pb-32">
            <ProductHeader
                isEditMode={isEditMode}
                onBack={() => router.push(`/agent/order/new/${id}`)}
            />

            <div className="max-w-md mx-auto px-6 pt-6">
                <ProductImage
                    image={selectedVariant?.image}
                    alt={data?.name || "Product"}
                />

                <ProductInfo name={data?.name} />

                <VariantSelector
                    variants={data?.variants || []}
                    selectedVariant={selectedVariant}
                    existingOrderItems={existingOrderItems}
                    selectedSizeGroup={selectedSizeGroup}
                    onSelect={handleVariantSelect}
                />

                <SizeGroupSelector
                    sizeGroups={sizeGroups}
                    selectedSizeGroup={selectedSizeGroup}
                    availableStock={availableStock}
                    sizeGroupMeta={sizeGroupMeta}
                    onSelect={handleSizeGroupSelect}
                />

                <QuantitySelector
                    quantity={quantity}
                    availableStock={availableStock}
                    disabled={isAlreadyAdded}
                    onChange={setQuantity}
                />

                {validationError && (
                    <div className="mb-6 p-4 bg-rose-50 border border-rose-100 rounded-2xl flex items-center gap-3 text-rose-500 animate-in fade-in slide-in-from-top-2">
                        <Info size={18} />
                        <p className="text-xs font-bold uppercase tracking-wider">
                            {validationError}
                        </p>
                    </div>
                )}

                <SubmitButton
                    isEditMode={isEditMode}
                    loading={loading}
                    disabled={availableStock === 0 || !!validationError}
                    onClick={handleSubmit}
                />
            </div>
        </div>
    );
}
