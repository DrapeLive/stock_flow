"use client";

import { customerApi } from "@/lib/api/customer";
import { CustomerAllResponse } from "@/types/customer";
import { ArrowRight, MapPin, Search, User } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { PageLoading } from "../ui/Loading";
import { useAuth } from "@/context/AuthContext";
import { agentApi } from "@/lib/api/agents";
import { orderApi } from "@/lib/api/order";
import { toastError } from "@/lib/toast";

const ListCustomer: React.FC = () => {
  const { user } = useAuth();
  const [data, setData] = useState<CustomerAllResponse>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await customerApi.getAll();
        setData(response);
      } catch (e) {
        console.error("Error fetching customers:", e);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  const handleSubmit = async (id: number) => {
    try {
      setLoading(true);
      const res = await agentApi.getProfile(user!.id);
      const agentIdValue = res.id;
      const res1 = await orderApi.create({
        customer: id,
        status: "DRAFT",
        agent: agentIdValue,
      });
      if (res1.id) {
        localStorage.setItem("orderKey", String(res1.id));
      }
      router.push(`/agent/order/new/${id}`);
    } catch {
      toastError("Error creating order. Please try again.");
      setLoading(false);
    }
  };

  if (loading) return <PageLoading />;

  const filteredData = data.filter(
    (c) =>
      c.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      c.address?.toLowerCase().includes(searchTerm.toLowerCase()),
  );

  if (data.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-gray-300">
        <User size={40} className="mb-4 opacity-20" />
        <h2 className="text-xl font-bold">No Customers Found</h2>
      </div>
    );
  }

  return (
    <div className="py-6 px-6">
      {/* Search Bar */}
      <div className="relative mb-6">
        <div className="absolute inset-y-0 left-4 flex items-center pointer-events-none text-gray-400">
          <Search size={18} />
        </div>
        <input
          type="text"
          placeholder="Search customer..."
          className="w-full bg-white border border-gray-100 rounded-2xl py-3 pl-12 pr-4 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/30 transition-all shadow-sm"
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
        />
      </div>

      <div className="space-y-3">
        {filteredData.map((customer, index) => (
          <button
            onClick={() => handleSubmit(customer.id)}
            key={index}
            className="flex w-full items-center gap-4 bg-white border border-gray-100 p-4 hover:border-primary/30 hover:shadow-md transition-all rounded-3xl group text-left active:scale-[0.98]"
          >
            <div className="w-12 h-12 rounded-2xl bg-gray-50 flex items-center justify-center border border-gray-100 shadow-sm flex-shrink-0 group-hover:bg-primary/5 group-hover:text-primary transition-colors">
              <span className="text-xl font-black text-gray-400 opacity-40 group-hover:text-primary/50">
                {customer.name.charAt(0).toUpperCase()}
              </span>
            </div>

            <div className="flex-1 min-w-0">
              <h6 className="font-bold text-gray-900 text-base truncate leading-tight">
                {customer.name}
              </h6>
              {customer.address && (
                <div className="flex items-center gap-1 mt-1">
                  <MapPin size={10} className="text-gray-300" />
                  <p className="text-xs text-gray-400 truncate leading-tight font-medium">
                    {customer.address}
                  </p>
                </div>
              )}
            </div>

            <div className="text-gray-200 group-hover:text-primary/40 transition-colors">
              <ArrowRight size={20} />
            </div>
          </button>
        ))}
      </div>
    </div>
  );
};

export default ListCustomer;
