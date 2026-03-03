"use client";
import { Plus } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { Info } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { CustomerAllResponse } from "@/types/customer";
import { customerApi } from "@/lib/api/customer";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";

const CustomerList: React.FC = () => {
  const { isAuthenticated } = useAuth();

  const [data, setData] = useState<CustomerAllResponse>([]);
  const [loading, setLoading] = useState(true);

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await customerApi.getAll();
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
    return <h2 className="flex justify-center">No Customer</h2>;
  return (
    <>
      <div className="pt-2 flex justify-between items-center px-4 mb-6">
        <div className="flex flex-col">
          <h2 className="text-xl font-extrabold text-gray-900 leading-tight">Customers</h2>
          <div className="flex gap-2 items-center mt-1">
            <span className="text-gray-400 text-[10px] font-bold uppercase tracking-wider">Total Active</span>
            <div className="bg-primary/10 text-primary rounded-full py-0.5 px-3 border border-primary/20">
              <span className="font-bold text-xs">{data.length}</span>
            </div>
          </div>
        </div>
        <StockFlowButton
          text="Add Customer"
          variant="filled"
          icon={<Plus className="size-4" />}
          onClick={() => router.push("/admin/users/customers/new")}
          className="shadow-lg shadow-primary/20 ring-1 ring-primary/10"
        />
      </div>
      <div className="px-4 space-y-3 pb-20">
        {data?.map((item) => (
          <div
            key={item.id}
            onClick={() => router.push(`/admin/users/customers/${item.id}/`)}
            className="flex items-center gap-4 bg-white border border-gray-100 p-4 hover:border-primary/30 hover:shadow-md transition-all rounded-2xl group cursor-pointer active:scale-[0.98]"
          >
            <div className="w-12 h-12 rounded-xl bg-gray-50 flex items-center justify-center border border-gray-100 shadow-sm flex-shrink-0">
              <span className="text-xl font-black text-gray-400 opacity-30">
                {item.name.charAt(0).toUpperCase()}
              </span>
            </div>

            <div className="flex-1 min-w-0">
              <h6 className="font-bold text-gray-900 text-base truncate leading-tight">
                {item.name}
              </h6>
              <p className="text-xs text-gray-400 truncate mt-1 leading-tight font-medium">
                {item.address || "No address provided"}
              </p>
              <div className="flex items-center gap-2 mt-2">
                <span className="text-[9px] bg-gray-50 text-gray-500 px-1.5 py-0.5 rounded-md uppercase font-bold tracking-tighter border border-gray-100">
                  {item.agent_name}
                </span>
                <span className="text-[9px] text-gray-300 font-bold uppercase tracking-widest">Agent</span>
              </div>
            </div>

            <div className="flex flex-col items-end justify-center px-4 border-l border-gray-50">
              <span className="text-[10px] text-gray-300 font-bold uppercase tracking-widest mb-1">Orders</span>
              <span className="text-lg font-black leading-none text-gray-900">
                {item.total_orders}
              </span>
            </div>

            <div className="text-gray-200 group-hover:text-primary/30 transition-colors pl-2">
              <Info size={18} />
            </div>
          </div>
        ))}
      </div>
    </>
  );
};

export default CustomerList;
