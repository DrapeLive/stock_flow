"use client";

import { useEffect, useState } from "react";
import { orderApi } from "@/lib/api/order";
import { customerApi } from "@/lib/api/customer";
import { toastError } from "@/lib/toast";
import { OrderAllResponse, PaginatedResponse } from "@/types/order";
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
import Pagination from "@/components/ui/Pagination";

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
  const [currentPage, setCurrentPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [pageSize, setPageSize] = useState(50);

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response: PaginatedResponse<OrderAllResponse[number]> = await orderApi.getAll({
          from: fromDate || undefined,
          to: toDate || undefined,
          page: currentPage,
          page_size: pageSize,
          search,
          customer: selectedCustomer !== "all" ? selectedCustomer : undefined,
        });
        setData(response.results);
        setTotalCount(response.count);
        setTotalPages(Math.ceil(response.count / pageSize));
      } catch (e) {
        console.error("Error fetching orders:", e);
        toastError("Failed to fetch orders", e);
        setLoadError(true);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [fromDate, toDate, currentPage, pageSize, search, selectedCustomer]);

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

  const order_len = pendingPacked.length;

  const handleClearFilters = () => {
    setFromDate("");
    setToDate("");
    setSelectedCustomer("all");
    setSearch("");
    setShowFilters(false);
    setCurrentPage(1);
  };

  const handleToggleFilters = () => {
    if (showFilters) {
      handleClearFilters();
    } else {
      setShowFilters(true);
    }
  };

  const handlePageChange = (page: number) => {
    setCurrentPage(page);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const handlePageSizeChange = (size: number) => {
    setPageSize(size);
    setCurrentPage(1);
  };

  if (loading) return <PageLoading />;
  if (loadError) return null;

  return (
    <div className="min-h-screen min-w-full">
      <OrderListHeader
        title="Remaining Orders"
        count={totalCount}
        showFilters={showFilters}
        handleToggleFilters={handleToggleFilters}
      />

      <div className="mb-4">
        <SearchBar
          value={search}
          onChange={(val) => {
            setSearch(val);
            setCurrentPage(1);
          }}
          placeholder="Search by customer or order ID..."
        />
      </div>

      <FilterBar
        fromDate={fromDate}
        toDate={toDate}
        onFromDateChange={(date) => {
          setFromDate(date);
          setCurrentPage(1);
        }}
        onToDateChange={(date) => {
          setToDate(date);
          setCurrentPage(1);
        }}
        customers={customers.map((c) => ({ id: c.id, name: c.name }))}
        selectedCustomer={selectedCustomer}
        onCustomerChange={(val) => {
          setSelectedCustomer(val);
          setCurrentPage(1);
        }}
        isOpen={showFilters}
        onClear={handleClearFilters}
      />

      {order_len === 0 ? (
        <EmptyState title={search || selectedCustomer !== "all" ? "No matching orders" : "No Active Orders"} />
      ) : (
        <div className="space-y-3 pb-32">
          {pendingPacked.map((order) => (
            <OrderCard
              key={order.id}
              order={order}
              onClick={() => router.push(`/agent/order/status/${order.id}`)}
            />
          ))}
        </div>
      )}

      <Pagination
        currentPage={currentPage}
        totalPages={totalPages}
        totalCount={totalCount}
        pageSize={pageSize}
        onPageChange={handlePageChange}
        onPageSizeChange={handlePageSizeChange}
      />
    </div>
  );
}
