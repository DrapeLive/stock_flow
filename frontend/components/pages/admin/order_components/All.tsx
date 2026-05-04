"use client";

import { useAuth } from "@/context/AuthContext";
import { orderApi } from "@/lib/api/order";
import { OrderAllResponse, PaginatedResponse } from "@/types/order";
import { Info } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { OrderCard } from "@/components/order";
import { OrderFilters } from "./types";
import { isOrderViewed } from "@/lib/viewedOrders";
import Pagination from "@/components/ui/Pagination";

interface Props {
  filters?: OrderFilters;
  search?: string;
  showUnreadOnly?: boolean;
  refreshKey?: number;
}

const All: React.FC<Props> = ({ filters, search, showUnreadOnly, refreshKey }) => {
  const { isAuthenticated } = useAuth();

  const [data, setData] = useState<OrderAllResponse>([]);
  const [loading, setLoading] = useState(true);
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
          ...filters,
          page: currentPage,
          page_size: pageSize,
          search,
        });
        const sorted = [...response.results].sort(
          (a, b) =>
            new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
        );
        setData(sorted);
        setTotalCount(response.count);
        setTotalPages(Math.ceil(response.count / pageSize));
      } catch (error) {
        console.error("Error fetching data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [isAuthenticated, router, filters, search, currentPage, pageSize, refreshKey]);

  const filteredData = showUnreadOnly
    ? data.filter((order) => !isOrderViewed(order.id))
    : data;

  const handlePageChange = (page: number) => {
    setCurrentPage(page);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const handlePageSizeChange = (size: number) => {
    setPageSize(size);
    setCurrentPage(1);
  };

  if (loading)
    return (
      <p className="text-center py-10 text-gray-400 font-medium">
        Loading orders...
      </p>
    );
  if (filteredData.length == 0)
    return (
      <div className="flex flex-col items-center justify-center py-20 text-gray-300">
        <Info size={40} className="mb-4 opacity-20" />
        <h2 className="text-xl font-bold">
          {showUnreadOnly
            ? "No unread orders"
            : search
              ? "No matching orders"
              : "No Data Found"}
        </h2>
      </div>
    );

  return (
    <div className="space-y-3 pb-20">
      {filteredData?.map((order) => (
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

export default All;
