"use client";
import { useAuth } from "@/context/AuthContext";
import { orderApi } from "@/lib/api/order";
import { OrderAllResponse, PaginatedResponse } from "@/types/order";
import groupOrders from "@/util/groupOrders";
import { Info } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { OrderCard } from "@/components/order";
import { OrderFilters } from "./types";
import { isOrderViewed } from "@/lib/viewedOrders";
import Pagination from "@/components/ui/Pagination";
import useSessionStorage from "@/hooks/useSessionStorage";

interface Props {
  filters?: OrderFilters;
  search?: string;
  showUnreadOnly?: boolean;
  refreshKey?: number;
  onTotalCountChange?: (total: number) => void;
  onPageChange?: (page: number) => void;
}

const Dispatched: React.FC<Props> = ({
  filters,
  search,
  showUnreadOnly,
  refreshKey,
  onTotalCountChange,
  onPageChange,
}) => {
  const { isAuthenticated } = useAuth();

  const [data, setData] = useState<OrderAllResponse>([]);
  const [loading, setLoading] = useState(true);
  const [currentPage, setCurrentPage] = useSessionStorage(
    "admin_Dispatched_currentPage",
    1,
  );
  const [totalCount, setTotalCount] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [pageSize, setPageSize] = useSessionStorage(
    "admin_Dispatched_pageSize",
    50,
  );

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response: PaginatedResponse<OrderAllResponse[number]> =
          await orderApi.getAll({
            ...filters,
            page: currentPage,
            page_size: pageSize,
            search,
            status: ["DISPATCHED"],
          });
        setData(response.results);
        setTotalCount(response.count);
        setTotalPages(Math.ceil(response.count / pageSize));
        // Report total count (or filtered count if unread only)
        const countToReport = showUnreadOnly
          ? response.results.filter((order) => !isOrderViewed(order.id)).length
          : response.count;
        onTotalCountChange?.(countToReport);
      } catch (error) {
        console.error("Error fetching data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [
    isAuthenticated,
    router,
    filters,
    search,
    currentPage,
    pageSize,
    refreshKey,
    showUnreadOnly,
    onTotalCountChange,
  ]);

  const filteredDispatched = showUnreadOnly
    ? data.filter((order) => !isOrderViewed(order.id))
    : data;

  const handlePageChange = (page: number) => {
    setCurrentPage(page);
    window.scrollTo({ top: 0, behavior: "smooth" });
    onPageChange?.(page);
  };

  const handlePageSizeChange = (size: number) => {
    setPageSize(size);
    setCurrentPage(1);
  };

  // Restore and save scroll position
  useEffect(() => {
    const saved = sessionStorage.getItem("admin_Dispatched_scrollY");
    if (saved) setTimeout(() => window.scrollTo(0, parseInt(saved)), 0);

    let timeout: NodeJS.Timeout;
    const saveScroll = () => {
      clearTimeout(timeout);
      timeout = setTimeout(() => {
        sessionStorage.setItem(
          "admin_Dispatched_scrollY",
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

  if (loading)
    return (
      <p className="text-center py-10 text-gray-400 font-medium">
        Loading dispatched orders...
      </p>
    );
  if (filteredDispatched.length == 0)
    return (
      <div className="flex flex-col items-center justify-center py-20 text-gray-300">
        <Info size={40} className="mb-4 opacity-20" />
        <h2 className="text-xl font-bold">
          {showUnreadOnly
            ? "No unread orders"
            : search
              ? "No matching orders"
              : "No Dispatched Orders"}
        </h2>
      </div>
    );

  return (
    <div className="space-y-3 pb-20">
      {filteredDispatched?.map((order) => (
        <OrderCard key={`${order.id}-${refreshKey}`} order={order} />
      ))}
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
};

export default Dispatched;
