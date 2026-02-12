"use client";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { useAuth } from "@/context/AuthContext";
import { adminApi } from "@/lib/api/admin";
import { AdminAllResponse } from "@/types/admin";
import { Info, Plus } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

const AdminsList: React.FC = () => {
  const { isAuthenticated } = useAuth();

  const [data, setData] = useState<AdminAllResponse>([]);
  const [loading, setLoading] = useState(true);

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await adminApi.getAll();
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
    return <h2 className="flex justify-center">No Agents</h2>;

  return (
    <>
      <div className="py-2 flex justify-between">
        <div className="flex gap-1 items-center">
          <p>Remaining Agents</p>
          <div className="bg-(--color-border) rounded-full py-0.5 px-2">
            <p className="font-bold">{data.length}</p>
          </div>
        </div>
        <StockFlowButton
          text="Add new Agent"
          variant="filled"
          icon={<Plus />}
          onClick={() => router.push("/admin/users/agents/new")}
        />
      </div>
      <div>
        {data?.map((item, index) => (
          <div
            className="flex border-b border-(--color-border) py-2 justify-between"
            key={index}
          >
            <div className="min-w-38">
              <h6>{item.username}</h6>
              <p className="text-(--color-text)">{item.email}</p>
            </div>
            <div className="flex w-fit justify-end">
              <Info />
            </div>
          </div>
        ))}
      </div>
    </>
  );
};

export default AdminsList;
