"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Image from "next/image";
import { ArrowLeft, PackagePlus, Minus, Plus, Check, Info } from "lucide-react";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { itemApi } from "@/lib/api/item";
import { orderApi } from "@/lib/api/order";
import { PageLoading } from "@/components/ui/Loading";
import { toastSuccess, toastError } from "@/lib/toast";
import type {
  ItemQRResponse,
  ItemVariant,
  ItemType,
} from "@/types/item";

import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  SIZES_BY_TYPE,
  SIZE_RANGE_TO_SIZES,
  FrontendSizeRange,
} from "@/types/item";

function getAvailableSizeRanges(
  variant: ItemVariant | null,
  type: ItemType | undefined,
): string[] {
  if (!variant || !type) return [];

  const variantSizes = Array.from(new Set(variant.sizes.map((s) => s.size)));
  const variantSizeSet = new Set(variantSizes);

  if (type === "gents") {
    for (const range of SIZES_BY_TYPE[type]) {
      const rangeSizes = SIZE_RANGE_TO_SIZES[range];
      const rangeSizeSet = new Set(rangeSizes);

      if (rangeSizeSet.size === variantSizeSet.size &&
          [...rangeSizeSet].every((s) => variantSizeSet.has(s))) {
        return [range];
      }
    }

    return variantSizes;
  }

  return SIZES_BY_TYPE[type].filter((range) => {
    const requiredSizes = SIZE_RANGE_TO_SIZES[range];
    return requiredSizes.every((s) => variantSizeSet.has(s));
  });
}

function getMaxSizeGroup(sizeGroups: string[]): string | null {
  if (sizeGroups.length === 0) return null;
  if (sizeGroups.length === 1) return sizeGroups[0];

  return sizeGroups.reduce((max, current) => {
    const maxSizes =
      SIZE_RANGE_TO_SIZES[max as FrontendSizeRange]?.length || 0;
    const currentSizes =
      SIZE_RANGE_TO_SIZES[current as FrontendSizeRange]?.length || 0;
    return currentSizes > maxSizes ? current : max;
  });
}

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
  const [loadingError, setLoadingError] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    const fetchData = async () => {
      try {
        const response = await itemApi.byqr(params.qr);
        setData(response);
        if (response.variants?.length > 0) {
          setSelectedVariant(
            response.variants.find(
              (v) => v.id === (response.matched_variant_id || 0),
            ) || response.variants[0],
          );
        }
      } catch (e) {
        console.error("Error fetching product details:", e);
        setLoadingError(true);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, [params.qr]);

  const sizeGroups = getAvailableSizeRanges(selectedVariant, data?.type);

  useEffect(() => {
    if (sizeGroups.length > 0 && !selectedSizeGroup) {
      setSelectedSizeGroup(getMaxSizeGroup(sizeGroups));
    }
  }, [sizeGroups, selectedSizeGroup]);

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

    setValidationError(null);

    try {
      setLoading(true);
      const orderKey = localStorage.getItem("orderKey");
      if (orderKey) {
        const orderId = parseInt(orderKey, 10);
        console.log(selectedVariant, selectedVariant.qr_code);
        await orderApi.addItem(orderId, {
          qr_code: selectedVariant.qr_code,
          quantity: quantity,
          size_group: selectedSizeGroup,
        });
        toastSuccess("Item Added Successfully");
        router.push(`/order/new/${id}`);
      } else {
        setValidationError(
          "Order session not found. Please restart the order.",
        );
      }
    } catch (e) {
      console.error("Error adding item to order:", e);
      toastError("Failed to add item", e);
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <PageLoading />;

  return (
    <div className="min-h-screen bg-gray-50/50 pb-32">
      <div className="bg-white border-b border-gray-100 px-6 py-6 sticky top-0 z-10">
        <div className="max-w-md mx-auto flex items-center justify-between">
          <div className="flex items-center gap-4">
            <button
              onClick={() => router.back()}
              className="p-2 rounded-xl hover:bg-gray-50 text-gray-400 transition-colors"
            >
              <ArrowLeft size={20} />
            </button>
            <div className="flex flex-col">
              <h1 className="text-xl font-black text-gray-900 leading-tight">
                Item Details
              </h1>
              <p className="text-[10px] text-gray-400 font-bold uppercase tracking-wider">
                Step 4: Configure Item
              </p>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-md mx-auto px-6 pt-6">
        <div className="bg-white rounded-[40px] overflow-hidden border-2 border-black mb-8 aspect-square relative">
          {selectedVariant?.image ? (
            <Image
              src={selectedVariant.image}
              alt={data?.name || "Product"}
              fill
              className="object-cover"
              unoptimized
            />
          ) : (
            <div className="w-full h-full bg-gray-50 flex items-center justify-center">
              <PackagePlus size={64} className="text-gray-200" />
            </div>
          )}
          <div className="absolute top-6 right-6 bg-white/90 backdrop-blur-md px-4 py-2 rounded-2xl shadow-sm border border-white/20">
            <span className="text-xs font-black uppercase tracking-widest text-primary">
              Live Preview
            </span>
          </div>
        </div>

        <div className="mb-8">
          <h2 className="text-2xl font-black text-gray-900 mb-1">
            {data?.name}
          </h2>
          <p className="text-[10px] text-gray-400 font-bold uppercase tracking-widest leading-tight">
            {"Premium Collection"}
          </p>
        </div>

        <div className="mb-8">
          <div className="flex p-2 gap-4 overflow-x-auto pb-2 scrollbar-none">
            {data?.variants.map((v, index) => (
              <button
                key={index}
                onClick={() => {
                  setSelectedVariant(v);
                  setValidationError(null);
                }}
                className={`relative flex-shrink-0 w-20 h-20 rounded-3xl border-2 transition-all overflow-hidden ${
                  selectedVariant?.id === v.id
                    ? "border border-primary scale-105"
                    : "border hover:border-gray-200"
                }`}
              >
                <Image
                  src={v.image || ""}
                  alt={`Variant ${index + 1}`}
                  fill
                  className="object-cover"
                  unoptimized
                />
                {selectedVariant?.id === v.id && (
                  <div className="absolute inset-0 bg-primary/20 flex items-center justify-center">
                    <Check className="text-white" size={24} strokeWidth={4} />
                  </div>
                )}
              </button>
            ))}
          </div>
        </div>

        <div className="mb-8">
          <h3 className="font-bold text-gray-900 mb-4">Size Group</h3>
          {sizeGroups.length > 0 ? (
            <Select
              value={selectedSizeGroup || undefined}
              onValueChange={(value) => {
                setSelectedSizeGroup(value);
                setValidationError(null);
              }}
            >
              <SelectTrigger className="w-full h-12 rounded-2xl border-2 border-gray-100 bg-white px-4">
                <SelectValue placeholder="Select size group" />
              </SelectTrigger>
              <SelectContent>
                {sizeGroups.map((group) => (
                  <SelectItem key={group} value={group}>
                    {group}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          ) : (
            <div className="w-full h-12 rounded-2xl border-2 border-gray-100 bg-gray-50 px-4 flex items-center text-gray-400 font-medium">
              No sizes available
            </div>
          )}
        </div>

        <div className="mb-10 bg-white p-6 rounded-[32px] border border-gray-100 flex items-center justify-between shadow-sm">
          <h3 className="font-bold text-gray-900">Quantity</h3>
          <div className="flex items-center gap-6">
            <button
              onClick={() => setQuantity(Math.max(1, quantity - 1))}
              className="w-10 h-10 rounded-xl border border-gray-100 flex items-center justify-center text-gray-400 hover:bg-gray-50 active:scale-90 transition-all font-bold"
            >
              <Minus size={20} />
            </button>

            <input
              type="number"
              min={1}
              value={quantity}
              onChange={(e) =>
                setQuantity(Math.max(1, parseInt(e.target.value, 10) || 1))
              }
              onFocus={(e) => e.target.select()}
              className="w-16 h-10 rounded-xl border border-gray-100 text-center text-xl font-black text-gray-900 focus:outline-none focus:border-gray-400 transition-colors [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
            />

            <button
              onClick={() => setQuantity(quantity + 1)}
              className="w-10 h-10 rounded-xl bg-gray-900 flex items-center justify-center text-white hover:bg-black active:scale-90 transition-all font-bold"
            >
              <Plus size={20} />
            </button>
          </div>
        </div>

        {validationError && (
          <div className="mb-6 p-4 bg-rose-50 border border-rose-100 rounded-2xl flex items-center gap-3 text-rose-500 animate-in fade-in slide-in-from-top-2">
            <Info size={18} />
            <p className="text-xs font-bold uppercase tracking-wider">
              {validationError}
            </p>
          </div>
        )}

        <div className="px-4">
          <StockFlowButton
            text="Add to Order"
            variant="filled"
            icon={<PackagePlus />}
            onClick={handleSubmit}
            className="w-full py-4 active:scale-95 transition-all"
          />
        </div>
      </div>
    </div>
  );
}
