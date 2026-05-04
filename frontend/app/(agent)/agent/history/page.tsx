"use client";

import { PageLoading } from "@/components/ui/Loading";
import { orderApi } from "@/lib/api/order";
import { customerApi } from "@/lib/api/customer";
import { toastError } from "@/lib/toast";
import { OrderAllResponse, PaginatedResponse } from "@/types/order";
import { CustomerAllResponse } from "@/types/customer";
import groupOrders from "@/util/groupOrders";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import OrderCard from "@/components/pages/agent/order/OrderCard";
import OrderListHeader from "@/components/pages/agent/order/OrderListHeader";
import EmptyState from "@/components/ui/EmptyState";
import SearchBar from "@/components/ui/SearchBar";
import Pagination from "@/components/ui/Pagination";
import useSessionStorage from "@/hooks/useSessionStorage";

export default function History() {
  const [data, setData] = useState<OrderAllResponse>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useSessionStorage("agent_history_search", "");
  const [customers, setCustomers] = useState<CustomerAllResponse>([]);
  const [selectedCustomer, setSelectedCustomer] = useSessionStorage(
    "agent_history_selectedCustomer",
    "all",
  );
  const [currentPage, setCurrentPage] = useSessionStorage(
    "agent_history_currentPage",
    1,
  );
  const [totalCount, setTotalCount] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [pageSize, setPageSize] = useSessionStorage(
    "agent_history_pageSize",
    50,
  );
  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response: PaginatedResponse<OrderAllResponse[number]> =
          await orderApi.getAll({
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
        toastError("Server Not Found", e);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [currentPage, pageSize, search, selectedCustomer]);

  useEffect(() => {
    customerApi
      .getAll()
      .then((customers) => {
        setCustomers(customers);
      })
      .catch(console.error);
  }, []);

  const { dispatched } = groupOrders(data ?? []);

  const order_len = dispatched.length;

  const handlePageChange = (page: number) => {
    setCurrentPage(page);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const handlePageSizeChange = (size: number) => {
    setPageSize(size);
    setCurrentPage(1);
  };

  // Restore and save scroll position
  useEffect(() => {
    const saved = sessionStorage.getItem("agent_history_scrollY");
    if (saved) setTimeout(() => window.scrollTo(0, parseInt(saved)), 0);

    let timeout: NodeJS.Timeout;
    const saveScroll = () => {
      clearTimeout(timeout);
      timeout = setTimeout(() => {
        sessionStorage.setItem(
          "agent_history_scrollY",
          window.scrollY.toString(),
        );
      }, 100);
    };

    window.addEventListener("scroll", saveScroll);
    return () => {
      window.removeEventListener("scroll", saveScroll);
      clearTimeout(timeout);
    };
  }, []);

  if (loading) return <PageLoading />;
  if (
    order_len === 0 &&
    !search &&
    selectedCustomer === "all" &&
    currentPage === 1
  )
    return <EmptyState title="No Dispatched Orders" />;

  return (
    <div className="min-h-screen min-w-full px-4 bg-gray-50/30">
      <OrderListHeader
        title="Dispatched Orders"
        count={totalCount}
        countColor="green"
        pageIndicator={
          currentPage > 1 ? (
            <div className="flex flex-row items-center gap-1 xs:gap-2">
              <p className="text-gray-400 font-medium text-xs whitespace-nowrap">
                Viewing page {currentPage}
              </p>
              <button
                onClick={() => {
                  setCurrentPage(1);
                  sessionStorage.removeItem("agent_history_scrollY");
                  window.scrollTo({ top: 0, behavior: "smooth" });
                }}
                className="text-[10px] px-2 py-0.5 bg-primary/10 text-primary rounded-full hover:bg-primary/20 transition-colors whitespace-nowrap"
                title="Reset to page 1"
              >
                Reset to page 1
              </button>
            </div>
          ) : undefined
        }
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

      {customers.length > 0 && (
        <div className="mb-4">
          <select
            value={selectedCustomer}
            onChange={(e) => {
              setSelectedCustomer(e.target.value);
              setCurrentPage(1);
            }}
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
        <EmptyState
          title={
            search || selectedCustomer !== "all"
              ? "No matching orders"
              : "No Dispatched Orders"
          }
        />
      ) : (
        <div className="space-y-3 pb-32">
          {dispatched.map((order) => (
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
