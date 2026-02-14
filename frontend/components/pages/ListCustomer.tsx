"use client";

import { useAuth } from "@/context/AuthContext";
import { customerApi } from "@/lib/api/customer";
import { CustomerAllResponse } from "@/types/customer";
import { ArrowRight } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

const ListCustomer: React.FC = () => {
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

  if (data.length == 0) {
    return <h2 className="flex justify-center items-center">No Customer</h2>;
  }

  if (loading) return <p>Loading</p>;

  return (
    <div className="py-4 px-5 min-h-screen">
      <div className="pb-2">
        <h4 className="font-medium">Select Customer</h4>
      </div>
      <div className="border border-(--color-border) rounded-md">
        {data.map((customer, index) => (
          <button
            onClick={() => router.push(`/order/new/${customer.id}`)}
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
