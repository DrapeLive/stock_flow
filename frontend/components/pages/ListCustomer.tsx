"use client";

import { customerApi } from "@/lib/api/customer";
import { CustomerAllResponse } from "@/types/customer";
import { ArrowRight } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { PageLoading } from "../ui/Loading";
import { AlertDestructive } from "../ui/AlertDestructive";
import { useAuth } from "@/context/AuthContext";
import { agentApi } from "@/lib/api/agents";
import { orderApi } from "@/lib/api/order";

const ListCustomer: React.FC = () => {
  const { user } = useAuth();
  const [data, setData] = useState<CustomerAllResponse>([]);
  const [loading, setLoading] = useState(true);

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await customerApi.getAll();
        setData(response);
      } catch (e) {
        <AlertDestructive heading="Error" description={"Server Not Found"} />;
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  const handleSubmit = async (id: number) => {
    try {
      setLoading(true);
      const res = await agentApi.getOne(user!.id);
      const agentIdValue = res.user.id;
      const res1 = await orderApi.create({
        agent: agentIdValue,
        customer: id,
        status: "PENDING",
      });
      if (res1.id) {
        localStorage.setItem("orderKey", String(res1.id));
      }
      router.push(`/order/new/${id}`);
    } catch {
      <AlertDestructive heading="Error" description={"Server Not Found"} />;
    } finally {
      setLoading(false);
    }
  };

  if (data.length == 0) {
    return <h2 className="flex justify-center items-center">No Customer</h2>;
  }

  if (loading) return <PageLoading />;

  return (
    <div className="py-4 px-5 min-h-screen">
      <div className="pb-2">
        <h4 className="font-medium">Select Customer</h4>
      </div>
      <div className="border border-(--color-border) rounded-md">
        {data.map((customer, index) => (
          <button
            onClick={() => handleSubmit(customer.id)}
            key={index}
            className="flex w-full justify-between items-center p-2.5 border-b border-(--color-border)"
          >
            <h4>{customer.name}</h4>
            <ArrowRight className="font-extrabold w-5 h-5" />
          </button>
        ))}
      </div>
    </div>
  );
};

export default ListCustomer;
