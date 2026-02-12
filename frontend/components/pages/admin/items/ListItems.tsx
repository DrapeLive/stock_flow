"use client";
import { useAuth } from "@/context/AuthContext";
import { itemApi } from "@/lib/api/item";
import { ItemAllResponse } from "@/types/item";
import { Info, Plus } from "lucide-react";
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
        <button className="p-1 rounded-md bg-(--color-primary) text-white border border-(--color-border)">
          <div className="flex items-center gap-1">
            <p>Add new Item</p>
            <Plus size={16} />
          </div>
        </button>
      </div>
      <div>
        {data?.map((item, index) => (
          <div
            className="flex justify-between border-b border-(--color-border) py-2"
            key={index}
          >
            <div className="min-w-12">
              <h6>{item.name}</h6>
              <p className="text-(--color-text) truncate">{item.address}</p>
            </div>
            <div className="flex flex-col items-center">
              <h6>{item.agent_name}</h6>
              <p className="text-(--color-text)">Agent</p>
            </div>
            <div className="flex flex-col items-center">
              <h3>{item.total_orders}</h3>
              <p className="text-(--color-text)">Order</p>
            </div>
            <Info />
          </div>
        ))}
      </div>
    </>
  );
};

export default ListItems;
