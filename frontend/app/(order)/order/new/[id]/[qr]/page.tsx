"use client";

import { useEffect, useState } from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { useParams } from "next/navigation";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import Image from "next/image";
import Link from "next/link";
import { ChevronLeft, PackagePlus } from "lucide-react";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { itemApi } from "@/lib/api/item";
import { ItemResponse, ItemSize, ItemVariant } from "@/types/item";
import { orderApi } from "@/lib/api/order";
import { useRouter } from "next/navigation";

export default function ProductDetailPage() {
  const params = useParams<{
    id: string;
    qr: string;
  }>();
  const id = params.id as string;

  const router = useRouter();

  const [data, setData] = useState<ItemResponse | null>(null);
  const [quantity, setQuantity] = useState<number>(1);
  const [selectedVariant, setSelectedVariant] = useState<ItemVariant>();
  const [selectedSize, setSelectedSize] = useState<ItemSize>();
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        console.log(params.qr);
        const response = await itemApi.byqr(params.qr);
        setData(response);
      } catch (error) {
        console.error("Error fetching data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  const handleSubmit = async () => {
    try {
      setLoading(true);
      const res = await orderApi.addItem(
        {
          qr_code: params.qr,
          quantity: quantity,
          size: selectedSize?.id || 0,
          variant: selectedVariant?.id || 0,
        },
        id,
      );
      if (res) {
        router.push(`order/new/${id}`);
      }
    } catch (e) {
      console.error("Error submitting data:", e);
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <h2>Loading</h2>;

  return (
    <div className="min-h-screen">
      <div className="w-full">
        <Link
          className="flex text-(--color-primary) items-center"
          href={"/order/new"}
        >
          <ChevronLeft size={18} />
          <h5>Back</h5>
        </Link>
      </div>
      <h2 className="pt-5">{data?.name}</h2>
      <Card className="w-full max-w-md border-none">
        <CardContent className="p-4 space-y-5">
          <div className="overflow-hidden">
            <Image
              src={selectedVariant?.image || ""}
              alt="product"
              className="w-full h-64 object-cover"
              width={100}
              height={64}
            />
          </div>

          <div className="space-y-2">
            <div className="flex gap-3 overflow-x-auto">
              {data?.variants.map((v) => (
                <button
                  key={v.id}
                  onClick={() => setSelectedVariant(v)}
                  className={`min-w-23 rounded-xl border pt-2 transition ${
                    selectedVariant?.id === v.id
                      ? "border-(--color-primary)"
                      : "border-gray-300"
                  }`}
                >
                  <Image
                    src={v.image}
                    alt={v.color}
                    className="w-full h-12 object-cover rounded"
                    height={12}
                    width={1}
                  />
                  <h6 className="mt-1 bg-white border-b rounded-b-xl">
                    {v.color}
                  </h6>
                </button>
              ))}
            </div>
          </div>

          <div className="w-full flex items-center justify-between">
            <h3>Quantity</h3>
            <Input
              type="number"
              min={1}
              value={quantity}
              onChange={(e) => setQuantity(Number(e.target.value))}
              className="w-20"
            />
          </div>

          <div className="w-full flex items-center justify-between">
            <h3>Size</h3>
            <Select
              value={String(selectedSize?.id)}
              onValueChange={(value) =>
                setSelectedSize(
                  data?.sizes.find((s) => s.id === Number(value)) ||
                    data?.sizes[0],
                )
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="Select size" />
              </SelectTrigger>
              <SelectContent>
                {data?.sizes.map((s) => (
                  <SelectItem key={s.id} value={String(s.id)}>
                    {s.size} — Stock: {s.stock}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* Add Button */}
          <div className="w-full flex justify-center p-9">
            <StockFlowButton
              text="Add Item"
              icon={<PackagePlus />}
              onClick={handleSubmit}
            />
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
