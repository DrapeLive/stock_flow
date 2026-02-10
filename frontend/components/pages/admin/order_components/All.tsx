"use client";

import { useAuth } from "@/context/AuthContext";
import { orderApi } from "@/lib/api/order";
import { OrderAllResponse } from "@/types/order";
import { Filter, Info } from "lucide-react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

const All: React.FC = () => {
  const { isAuthenticated } = useAuth();

  const [data, setData] = useState<OrderAllResponse>([]);
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
  if (data.length == 0) <h2 className="flex justify-center">No Data</h2>;
  return (
    <>
      <div className="pt-2 flex justify-between">
        <div className="flex gap-1 items-center">
          <p>Remaining Order</p>
          <div className="bg-(--color-border) rounded-full py-0.5 px-2">
            <p className="font-bold">{data.length}</p>
          </div>
        </div>
        <div className="p-0.5 rounded-[3px] border border-(--color-border)">
          <Filter className="text-(--color-border) w-2.5 h-2.5" />
        </div>
      </div>
      <div className="space-y-2 pt-2">
        {data?.map((order) => {
          const previewImages = order.items.slice(0, 3);

          return (
            <div key={order.id} className="flex p-1 border-b">
              <div className="relative w-16 h-16">
                {previewImages[0] && (
                  <div className="absolute left-0 z-30 rotate-0">
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
                  <div className="absolute left-0 z-20 rotate-10">
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
                  <div className="absolute left-0 z-10 rotate-20">
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

              <div className="flex flex-col px-2 justify-center gap-2 max-h-full">
                <h6 className="font-medium">{order.customer_details.name}</h6>
                <p className="max-w-30 truncate whitespace-nowrap">
                  {order.items.map((item) => (
                    <span className="text-(--color-text) mr-1" key={item.id}>
                      {item.item.name}
                    </span>
                  ))}
                </p>
              </div>

              <div className="flex items-center pr-2">
                <div
                  className={
                    order.status == "PENDING"
                      ? "bg-(--color-pending)/20 border border-(--color-pending) text-(--color-pending) rounded-full px-1 py-0.5"
                      : order.status == "PACKED"
                        ? "bg-(--color-packed)/20 border border-(--color-packed) text-(--color-packed) rounded-full px-1 py-0.5"
                        : "bg-(--color-dispatched)/20 border border-(--color-dispatched) text-(--color-dispatched) rounded-full px-1 py-0.5"
                  }
                >
                  <p>{order.status}</p>
                </div>
              </div>

              <div className="px-4 flex text-center justify-center flex-col">
                <h3>{order.total_quantity}</h3>
                <p className="text-(--color-text)">Pieces</p>
              </div>
              <div className="flex justify-center items-center">
                <Info />
              </div>
            </div>
          );
        })}
      </div>
    </>
  );
};

export default All;
