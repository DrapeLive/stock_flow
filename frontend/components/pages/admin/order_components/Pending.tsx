"use client";
import { useAuth } from "@/context/AuthContext";
import { orderApi } from "@/lib/api/order";
import { OrderAllResponse } from "@/types/order";
import groupOrders from "@/util/groupOrders";
import { Info } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { OrderCard } from "@/components/order";
import { OrderFilters } from "./types";
import { isOrderViewed } from "@/lib/viewedOrders";

interface Props {
  filters?: OrderFilters;
  search?: string;
  showUnreadOnly?: boolean;
  refreshKey?: number;
}

const Pending: React.FC<Props> = ({ filters, search, showUnreadOnly, refreshKey }) => {
  const { isAuthenticated } = useAuth();

  const [data, setData] = useState<OrderAllResponse>([]);
  const [loading, setLoading] = useState(true);

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await orderApi.getAll(filters);
        setData(response);
      } catch (error) {
        console.error("Error fetching data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [isAuthenticated, router, filters]);

  const { pending } = groupOrders(data ?? []);

  const filteredPending = search || showUnreadOnly
    ? pending.filter((order) => {
        const s = search?.toLowerCase();
        const matchesSearch = s
          ? order.customer_details?.name?.toLowerCase().includes(s) ||
            order.agent_details?.username?.toLowerCase().includes(s) ||
            order.id.toString().includes(s)
          : true;

        const matchesUnread = showUnreadOnly ? !isOrderViewed(order.id) : true;

        return matchesSearch && matchesUnread;
      })
    : pending;

  if (loading)
    return (
      <p className="text-center py-10 text-gray-400 font-medium">
        Loading pending orders...
      </p>
    );
  if (filteredPending.length == 0)
    return (
      <div className="flex flex-col items-center justify-center py-20 text-gray-300">
        <Info size={40} className="mb-4 opacity-20" />
        <h2 className="text-xl font-bold">
          {showUnreadOnly
            ? "No unread orders"
            : search
              ? "No matching orders"
              : "No Pending Orders"}
        </h2>
      </div>
    );

  return (
    <div className="space-y-3 pb-20">
      {filteredPending?.map((order) => (
        <OrderCard key={`${order.id}-${refreshKey}`} order={order} />
      ))}
    </div>
  );
};

export default Pending;
