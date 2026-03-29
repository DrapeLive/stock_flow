"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Image from "next/image";
import { ArrowLeft, PackagePlus, Minus, Plus, Check, Info } from "lucide-react";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { itemApi } from "@/lib/api/item";
import { orderApi } from "@/lib/api/order";
import { PageLoading } from "@/components/ui/Loading";
import { SuccessAlert } from "@/components/ui/SuccessAlert";
import { FailedBox } from "@/components/ui/FailBox";
import type { ItemQRResponse, ItemVariant } from "@/types/item";

interface VariantOption {
  image: string;
  size: string;
  variant_id: number;
  stock: number;
  qr_code: string;
}

const SIZE_GROUPS: Record<string, string[]> = {
  gents: ["S,M,L,XL", "M,L,XL,XXL", "M,L,XL"],
  kids: ["20-36", "20-30", "26-36", "26-38", "20-38"],
};

export default function ProductDetailPage() {
  const params = useParams<{ id: string; qr: string }>();
  const id = params.id as string;
  const router = useRouter();

  const [data, setData] = useState<ItemQRResponse | null>(null);
  const [quantity, setQuantity] = useState<number>(1);
  const [selectedVariant, setSelectedVariant] = useState<ItemVariant | null>(null);
  const [selectedSizeGroup, setSelectedSizeGroup] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    const fetchData = async () => {
      try {
        const response = await itemApi.byqr(params.qr);
        setData(response);
        if (response.variants?.length > 0) {
          setSelectedVariant(response.variants[0]);
        }
      } catch (e) {
        console.error("Error fetching product details:", e);
        setError(true);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, [params.qr]);

  const sizeGroups: string[] = data?.type
    ? (SIZE_GROUPS[data.type.toLowerCase()] ?? [])
    : [];

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
        await orderApi.addItem(orderId, {
          qr_code: params.qr,
          quantity: quantity,
          size_group: selectedSizeGroup,
        });
        setSuccess(true);
      } else {
        setValidationError("Order session not found. Please restart the order.");
      }
    } catch (e) {
      console.error("Error adding item to order:", e);
      setError(true);
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <PageLoading />;

  if (success)
    return (
      <SuccessAlert
        title="Success"
        description="Item Added Successfully"
        onClose={() => router.push(`/order/new/${id}`)}
      />
    );

  if (error)
    return (
      <FailedBox
        title="Failed"
        description="Server Error"
        onClose={() => router.push(`/order/new/${id}/scanner`)}
      />
    );

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
        <div className="bg-white rounded-[40px] overflow-hidden shadow-xl shadow-primary/5 border border-gray-100 mb-8 aspect-square relative">
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
          <div className="flex gap-4 overflow-x-auto pb-2 scrollbar-none">
            {data?.variants.map((v, index) => (
              <button
                key={index}
                onClick={() => {
                  setSelectedVariant(v);
                  setValidationError(null);
                }}
                className={`relative flex-shrink-0 w-20 h-20 rounded-3xl border-2 transition-all overflow-hidden ${
                  selectedVariant?.id === v.id
                    ? "border-primary scale-105 shadow-lg shadow-primary/20"
                    : "border-transparent hover:border-gray-200"
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

        {sizeGroups.length > 0 && (
          <div className="mb-8">
            <h3 className="font-bold text-gray-900 mb-4">Select Size Group</h3>
            <div className="flex flex-wrap gap-3">
              {sizeGroups.map((group) => (
                <button
                  key={group}
                  onClick={() => {
                    setSelectedSizeGroup(group);
                    setValidationError(null);
                  }}
                  className={`px-6 py-3 rounded-2xl font-black text-sm transition-all border-2 ${
                    selectedSizeGroup === group
                      ? "bg-primary border-primary text-white shadow-lg shadow-primary/20 scale-105"
                      : "bg-white border-gray-100 text-gray-600 hover:border-gray-200"
                  }`}
                >
                  {group}
                </button>
              ))}
            </div>
          </div>
        )}

        <div className="mb-10 bg-white p-6 rounded-[32px] border border-gray-100 flex items-center justify-between shadow-sm">
          <h3 className="font-bold text-gray-900">Quantity</h3>
          <div className="flex items-center gap-6">
            <button
              onClick={() => setQuantity(Math.max(1, quantity - 1))}
              className="w-10 h-10 rounded-xl border border-gray-100 flex items-center justify-center text-gray-400 hover:bg-gray-50 active:scale-90 transition-all font-bold"
            >
              <Minus size={20} />
            </button>
            <span className="text-xl font-black text-gray-900 w-8 text-center">
              {quantity}
            </span>
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
            className="w-full py-8 rounded-[32px] shadow-xl shadow-primary/30 text-lg active:scale-95 transition-all"
          />
        </div>
      </div>
    </div>
  );
}
