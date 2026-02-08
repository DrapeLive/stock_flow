"use client";

import { Filter, Search } from "lucide-react";
import { Input } from "@/components/ui/input";
import { useEffect, useState } from "react";
import { orderApi } from "@/lib/api/order";
import { OrderAllResponse } from "@/types/order";
import { useAuth } from "@/context/AuthContext";
import { useRouter } from "next/navigation";
import Image from "next/image";

export default function Home() {
  const { isAuthenticated } = useAuth();

  const [data, setData] = useState<OrderAllResponse>();
  const [loading, setLoading] = useState(true);

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    if (!isAuthenticated) {
      router.push("/login");
      return;
    }

    const fetchData = async () => {
      try {
        const response = await orderApi.getAll();
        setData(response);
        console.log(response);
      } catch (error) {
        console.error("Error fetching data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [isAuthenticated, router]);

  if (loading) return <p>Loading</p>;

  return (
    <div className="min-h-screen min-w-full">
      <div className="relative">
        <div className="text-muted-foreground pointer-events-none absolute inset-y-0 left-0 flex items-center justify-center pl-3 peer-disabled:opacity-50">
          <Search className="size-4" />
        </div>
        <Input
          type="text"
          placeholder="search orders.."
          className="peer pl-9 py-6"
        />
      </div>
      <div className="pt-3 flex justify-between">
        <div className="flex gap-1 items-center">
          <p>Remaining Order</p>
          <div className="bg-(--color-border) rounded-full py-0.5 px-2">
            <p className="font-bold">40</p>
          </div>
        </div>
        <div className="p-0.5 rounded-[3px] border border-(--color-border)">
          <Filter className="text-(--color-border) w-2.5 h-2.5" />
        </div>
      </div>
      <div className="space-y-3 pt-3">
        {data?.map((order) => {
          const previewImages = order.items.slice(0, 3);

          return (
            <div
              key={order.id}
              className="flex items-center justify-between p-3 border rounded-xl shadow-sm"
            >
              {/* LEFT — stacked images */}
              <div className="relative w-20 h-16">
                {previewImages[0] && (
                  <div className="absolute left-0 z-30 rotate-[-12deg]">
                    <Image
                      src={previewImages[0].variant.image}
                      alt={previewImages[0].item.name}
                      width={56}
                      height={56}
                      className="rounded-md object-cover border bg-white shadow"
                    />
                  </div>
                )}

                {previewImages[1] && (
                  <div className="absolute left-3 z-20 rotate-[6deg]">
                    <Image
                      src={previewImages[1].variant.image}
                      alt={previewImages[1].item.name}
                      width={56}
                      height={56}
                      className="rounded-md object-cover border bg-white shadow"
                    />
                  </div>
                )}

                {previewImages[2] && (
                  <div className="absolute left-6 z-10 rotate-0">
                    <Image
                      src={previewImages[2].variant.image}
                      alt={previewImages[2].item.name}
                      width={56}
                      height={56}
                      className="rounded-md object-cover border bg-white shadow"
                    />
                  </div>
                )}
              </div>

              {/* CENTER */}
              <div className="flex-1 px-3">
                <p className="font-semibold">{order.customer_details.name}</p>
                <p className="text-sm text-muted-foreground">
                  {order.items.length} items
                </p>
              </div>

              {/* RIGHT */}
              <div className="text-lg font-bold">{order.total_quantity}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
