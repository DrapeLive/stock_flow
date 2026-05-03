"use client";

import { useEffect, useState } from "react";
import { orderApi } from "@/lib/api/order";
import { customerApi } from "@/lib/api/customer";
import { toastError } from "@/lib/toast";
import { OrderAllResponse } from "@/types/order";
import { CustomerAllResponse } from "@/types/customer";
import groupOrders from "@/util/groupOrders";
import { PageLoading } from "@/components/ui/Loading";
import { useRouter } from "next/navigation";
import OrderCard from "@/components/pages/agent/order/OrderCard";
import OrderListHeader from "@/components/pages/agent/order/OrderListHeader";
import EmptyState from "@/components/ui/EmptyState";
import FilterBar from "@/components/ui/FilterBar";
import FilterToggle from "@/components/ui/FilterToggle";
import SearchBar from "@/components/ui/SearchBar";

export default function Home() {
  const [data, setData] = useState<OrderAllResponse>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(false);
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");
  const [showFilters, setShowFilters] = useState(false);
  const [search, setSearch] = useState("");
  const [customers, setCustomers] = useState<CustomerAllResponse>([]);
  const [selectedCustomer, setSelectedCustomer] = useState("all");

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await orderApi.getAll({
          from: fromDate || undefined,
          to: toDate || undefined,
        });
        setData(response);
      } catch (e) {
        console.error("Error fetching orders:", e);
        toastError("Failed to fetch orders", e);
        setLoadError(true);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [fromDate, toDate]);

  useEffect(() => {
    customerApi
      .getAll()
      .then((customers) => {
        setCustomers(customers);
      })
      .catch(console.error);
  }, []);

  const sortedData = [...data].sort(
    (a, b) =>
      new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
  );

  const { pendingPacked } = groupOrders(sortedData);

  const filteredOrders = pendingPacked.filter((order) => {
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

  const handleClearFilters = () => {
    setFromDate("");
    setToDate("");
    setSelectedCustomer("all");
    setSearch("");
    setShowFilters(false);
  };

  const handleToggleFilters = () => {
    if (showFilters) {
      handleClearFilters();
    } else {
      setShowFilters(true);
    }
  };

  if (loading) return <PageLoading />;
  if (loadError) return null;

  return (
    <div className="min-h-screen min-w-full">
      <OrderListHeader
        title="Remaining Orders"
        count={order_len}
        showFilters={showFilters}
        handleToggleFilters={handleToggleFilters}
      />

      <div className="mb-4">
        <SearchBar
          value={search}
          onChange={setSearch}
          placeholder="Search by customer or order ID..."
        />
      </div>

      <FilterBar
        fromDate={fromDate}
        toDate={toDate}
        onFromDateChange={setFromDate}
        onToDateChange={setToDate}
        customers={customers.map((c) => ({ id: c.id, name: c.name }))}
        selectedCustomer={selectedCustomer}
        onCustomerChange={setSelectedCustomer}
        isOpen={showFilters}
        onClear={handleClearFilters}
      />

      {order_len === 0 ? (
        <EmptyState title={search || selectedCustomer !== "all" ? "No matching orders" : "No Active Orders"} />
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
