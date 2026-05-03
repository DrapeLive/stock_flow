"use client";

import { PageLoading } from "@/components/ui/Loading";
import { orderApi } from "@/lib/api/order";
import { customerApi } from "@/lib/api/customer";
import { toastError } from "@/lib/toast";
import { OrderAllResponse } from "@/types/order";
import { CustomerAllResponse } from "@/types/customer";
import groupOrders from "@/util/groupOrders";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import OrderCard from "@/components/pages/agent/order/OrderCard";
import OrderListHeader from "@/components/pages/agent/order/OrderListHeader";
import EmptyState from "@/components/ui/EmptyState";
import SearchBar from "@/components/ui/SearchBar";

export default function History() {
  const [data, setData] = useState<OrderAllResponse>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [customers, setCustomers] = useState<CustomerAllResponse>([]);
  const [selectedCustomer, setSelectedCustomer] = useState("all");
  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await orderApi.getAll();
        setData(response);
      } catch (e) {
        console.error("Error fetching orders:", e);
        toastError("Server Not Found", e);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  useEffect(() => {
    customerApi
      .getAll()
      .then((customers) => {
        setCustomers(customers);
      })
      .catch(console.error);
  }, []);

  const { dispatched } = groupOrders(data ?? []);

  const filteredOrders = dispatched.filter((order) => {
    if (selectedCustomer !== "all" && order.customer_details?.id !== Number(selectedCustomer)) {
      return false;
    }
    if (search) {
      const s = search.toLowerCase();
      return (
        order.customer_details?.name?.toLowerCase().includes(s) ||
        order.agent_details?.username?.toLowerCase().includes(s) ||
        order.id.toString().includes(s)
      );
    }
    return true;
  });

  const order_len = filteredOrders.length;

  if (loading) return <PageLoading />;
  if (order_len === 0 && !search && selectedCustomer === "all")
    return <EmptyState title="No Dispatched Orders" />;

  return (
    <div className="min-h-screen min-w-full px-4 bg-gray-50/30">
      <OrderListHeader
        title="Dispatched Orders"
        count={order_len}
        countColor="green"
      />

      <div className="mb-4">
        <SearchBar
          value={search}
          onChange={setSearch}
          placeholder="Search by customer or order ID..."
        />
      </div>

      {customers.length > 0 && (
        <div className="mb-4">
          <select
            value={selectedCustomer}
            onChange={(e) => setSelectedCustomer(e.target.value)}
            className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-primary/30 text-sm bg-white"
          >
            <option value="all">All Customers</option>
            {customers.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </div>
      )}

      {order_len === 0 ? (
        <EmptyState title={search || selectedCustomer !== "all" ? "No matching orders" : "No Dispatched Orders"} />
      ) : (
        <div className="space-y-3 pb-32">
          {filteredOrders.map((order) => (
            <OrderCard
              key={order.id}
              order={order}
              onClick={() => router.push(`/agent/order/status/${order.id}`)}
            />
          ))}
        </div>
      )}
    </div>
  );
}
