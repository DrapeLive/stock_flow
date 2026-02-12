"use client";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { useAuth } from "@/context/AuthContext";
import { agentApi } from "@/lib/api/agents";
import { AgentAllResponse } from "@/types/agent";
import { Info, Plus } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

const AgentsList: React.FC = () => {
  const { isAuthenticated } = useAuth();

  const [data, setData] = useState<AgentAllResponse>([]);
  const [loading, setLoading] = useState(true);

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await agentApi.getAll();
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
            className="flex border-b border-(--color-border) py-2"
            key={index}
          >
            <div className="min-w-38">
              <h6>{item.user.username}</h6>
              <p className="text-(--color-text)">{item.user.email}</p>
            </div>
            <div className="flex w-full justify-between">
              <h6 className="flex items-center">+91 {item.contact}</h6>
              <div className="flex flex-col items-center">
                <h3>{item.total_customers}</h3>
                <p className="text-(--color-text)">Customers</p>
              </div>
              <Info />
            </div>
          </div>
        ))}
      </div>
    </>
  );
};

export default AgentsList;
