"use client";
import { Button } from "@/components/ui/button";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { useAuth } from "@/context/AuthContext";
import { itemApi } from "@/lib/api/item";
import { ItemAllResponse } from "@/types/item";
import { Info, Plus, Printer } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

const ListItems: React.FC = () => {
  const { isAuthenticated } = useAuth();

  const [data, setData] = useState<ItemAllResponse>([]);
  const [loading, setLoading] = useState(true);

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await itemApi.getAll();
        setData(response);
      } catch (error) {
        console.error("Error fetching data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [isAuthenticated, router]);

  if (loading) {
    return <h2 className="flex justify-center">Loading</h2>;
  }
  if (data.length == 0)
    return <h2 className="flex justify-center">No Items</h2>;
  return (
    <>
      <div className="pt-2 flex justify-between">
        <div className="flex gap-1 items-center">
          <p>Total Item</p>
          <div className="bg-(--color-border) rounded-full py-0.5 px-2">
            <p className="font-bold">{data.length}</p>
          </div>
        </div>
        <StockFlowButton
          text="Add new Item"
          icon={<Plus />}
          onClick={() => router.push("/admin/items/new")}
        />
      </div>
      <div>
        {data?.map((item, index) => (
          <div
            className="grid grid-cols-4 border-b border-(--color-border) py-2"
            key={index}
          >
            <div className="flex flex-col justify-center">
              <h6 className="truncate">{item.name}</h6>
              <p className="text-(--color-text) truncate">{item.description}</p>
            </div>
            <div className="flex flex-col gap-2 items-center">
              <h6>
                {item.sizes
                  .map((sizeInfo) => sizeInfo.size.toUpperCase())
                  .join(", ")}
              </h6>
              <h6>
                {item.variants
                  .map((sizeInfo) => sizeInfo.color.toUpperCase())
                  .join(", ")}
              </h6>
            </div>
            <div className="flex justify-center items-center">
              {/*<h3>{item.sizes}</h3>*/}
              <p>
                {item.sizes.reduce(
                  (total, sizeInfo) => total + sizeInfo.stock,
                  0,
                )}
              </p>
            </div>
            <div className="flex justify-end items-center gap-2">
              <Button onClick={() => router.push("/admin/items/qr/" + item.id)}>
                <Printer />
              </Button>
              <Info />
            </div>
          </div>
        ))}
      </div>
    </>
  );
};

export default ListItems;
