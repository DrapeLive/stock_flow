"use client";

import { useEffect, useState, Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { CheckCheck } from "lucide-react";
import { agentApi } from "@/lib/api/agents";
import { customerApi } from "@/lib/api/customer";
import { orderApi } from "@/lib/api/order";
import Packed from "@/components/pages/admin/order_components/Packed";
import Pending from "@/components/pages/admin/order_components/Pending";
import Dispatched from "@/components/pages/admin/order_components/Dispatched";
import All from "@/components/pages/admin/order_components/All";
import FilterBar from "@/components/ui/FilterBar";
import FilterToggle from "@/components/ui/FilterToggle";
import SearchBar from "@/components/ui/SearchBar";
import { OrderFilters } from "@/components/pages/admin/order_components/types";
import { getViewedOrdersCount, markAllAsRead } from "@/lib/viewedOrders";

type Tab = "All" | "Packed" | "Pending" | "Dispatched";

interface SimpleAgent {
  id: number;
  username: string;
}

interface SimpleCustomer {
  id: number;
  name: string;
}

function AdminHomePageContent() {
  const searchParams = useSearchParams();
  const [activeTab, setActiveTab] = useState<Tab>("Pending");

  useEffect(() => {
    const saved = sessionStorage.getItem("adminOrdersActiveTab") as Tab | null;
    if (saved) setActiveTab(saved);
  }, []);

  const handleTabChange = (tab: Tab) => {
    setActiveTab(tab);
    sessionStorage.setItem("adminOrdersActiveTab", tab);
  };

  const [filters, setFilters] = useState<OrderFilters>({});
  const [agents, setAgents] = useState<SimpleAgent[]>([]);
  const [customers, setCustomers] = useState<SimpleCustomer[]>([]);
  const [showFilters, setShowFilters] = useState(false);
  const [search, setSearch] = useState("");
  const [orderCounts, setOrderCounts] = useState<Record<string, number>>({});
  const [showUnreadOnly, setShowUnreadOnly] = useState(false);
  const [allOrderIds, setAllOrderIds] = useState<number[]>([]);
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    agentApi
      .getAll()
      .then((agents) => {
        setAgents(agents.map((a) => ({ id: a.id, username: a.user.username })));
      })
      .catch(console.error);
  }, []);

  useEffect(() => {
    customerApi
      .getAll()
      .then((customers) => {
        setCustomers(customers.map((c) => ({ id: c.id, name: c.name })));
      })
      .catch(console.error);
  }, []);

  useEffect(() => {
    orderApi
      .getAll()
      .then((orders) => {
        const allIds = orders.map((o) => o.id);
        setAllOrderIds(allIds);
        const pendingIds = orders
          .filter((o) => o.status === "PENDING")
          .map((o) => o.id);
        const packedIds = orders
          .filter((o) => o.status === "PACKED")
          .map((o) => o.id);
        const dispatchedIds = orders
          .filter((o) => o.status === "DISPATCHED")
          .map((o) => o.id);
        setOrderCounts({
          all: getViewedOrdersCount(allIds),
          pending: getViewedOrdersCount(pendingIds),
          packed: getViewedOrdersCount(packedIds),
          dispatched: getViewedOrdersCount(dispatchedIds),
        });
      })
      .catch(console.error);
  }, [search, filters]);

  useEffect(() => {
    const customerId = searchParams.get("customer");
    const agentId = searchParams.get("agent");
    const from = searchParams.get("from");
    const to = searchParams.get("to");

    const newFilters: OrderFilters = {};
    if (customerId) newFilters.customer = customerId;
    if (agentId) newFilters.agent = agentId;
    if (from) newFilters.from = from;
    if (to) newFilters.to = to;

    if (Object.keys(newFilters).length > 0) {
      setFilters(newFilters);
      setShowFilters(true);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchParams]);

  const handleFromDateChange = (date: string) => {
    setFilters((prev) => ({ ...prev, from: date || undefined }));
  };

  const handleToDateChange = (date: string) => {
    setFilters((prev) => ({ ...prev, to: date || undefined }));
  };

  const handleAgentChange = (agentId: string) => {
    setFilters((prev) => ({
      ...prev,
      agent: agentId === "all" ? undefined : agentId,
    }));
  };

  const handleCustomerChange = (customerId: string) => {
    setFilters((prev) => ({
      ...prev,
      customer: customerId === "all" ? undefined : customerId,
    }));
  };

  const handleClearFilters = () => {
    setFilters({});
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

  const renderContent = (): React.ReactNode => {
    const commonProps = { filters, search, showUnreadOnly, refreshKey };
    switch (activeTab) {
      case "Packed":
        return <Packed {...commonProps} />;
      case "Pending":
        return <Pending {...commonProps} />;
      case "Dispatched":
        return <Dispatched {...commonProps} />;
      default:
        return <All {...commonProps} />;
    }
  };

  const handleMarkAllRead = () => {
    markAllAsRead(allOrderIds);
    setRefreshKey((prev) => prev + 1);
    // Refresh counts
    orderApi
      .getAll()
      .then((orders) => {
        setAllOrderIds(orders.map((o) => o.id));
        const allIds = orders.map((o) => o.id);
        const pendingIds = orders
          .filter((o) => o.status === "PENDING")
          .map((o) => o.id);
        const packedIds = orders
          .filter((o) => o.status === "PACKED")
          .map((o) => o.id);
        const dispatchedIds = orders
          .filter((o) => o.status === "DISPATCHED")
          .map((o) => o.id);
        setOrderCounts({
          all: getViewedOrdersCount(allIds),
          pending: getViewedOrdersCount(pendingIds),
          packed: getViewedOrdersCount(packedIds),
          dispatched: getViewedOrdersCount(dispatchedIds),
        });
      })
      .catch(console.error);
  };

  const getActiveTabCount = () => {
    const statusMap: Record<Tab, string> = {
      All: "all",
      Pending: "pending",
      Packed: "packed",
      Dispatched: "dispatched",
    };
    return orderCounts[statusMap[activeTab]] || 0;
  };

  return (
    <div className="min-h-screen min-w-full">
      <div className="p-1.5 mt-2 flex items-center space-x-1 border border-gray-200 rounded-md mb-2 overflow-x-auto">
        {(["All", "Pending", "Packed", "Dispatched"] as Tab[]).map((tab) => {
          const count = orderCounts[tab.toLowerCase()];
          return (
            <button
              key={tab}
              onClick={() => handleTabChange(tab)}
              className={`flex-shrink-0 rounded-md flex-1 min-w-fit px-3 py-2 font-bold text-xs transition-all duration-300 relative ${
                activeTab === tab
                  ? "bg-primary text-white ring-1 ring-primary/10"
                  : "text-gray-500 hover:text-gray-700 hover:bg-gray-100/80"
              }`}
            >
              {tab}
              {count > 0 && (
                <span className="absolute -top-1 -right-1 bg-red-500 text-white text-[9px] font-bold rounded-full w-4 h-4 flex items-center justify-center">
                  {count > 99 ? "99+" : count}
                </span>
              )}
            </button>
          );
        })}
      </div>
      <div className="flex flex-row justify-between items-start sm:items-center gap-2 mt-4 mb-2">
        <div className="flex items-center gap-1">
          <span className="text-gray-400 text-[10px] font-bold uppercase">
            Total Orders
          </span>
          <div className="bg-amber-100 text-amber-600 border border-amber-200 rounded-full w-6 h-6 flex justify-center items-center">
            <span className="font-bold text-xs">{getActiveTabCount()}</span>
          </div>
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <button
            onClick={() => setShowUnreadOnly(!showUnreadOnly)}
            className={`text-xs px-3 py-1.5 rounded-full border transition-all ${
              showUnreadOnly
                ? "bg-primary text-white border-primary shadow-lg shadow-primary/20"
                : "text-gray-500 border-gray-200 hover:bg-gray-100"
            }`}
          >
            Unread Only
          </button>
          <button
            onClick={handleMarkAllRead}
            className="text-xs px-3 py-1.5 rounded-full border transition-all p-1.5 text-gray-500 border-gray-200 hover:bg-gray-100"
            title="Mark all as read"
          >
            Mark All as Read
          </button>
        </div>
      </div>
      <div className="flex items-center justify-between gap-2 mb-4">
        <SearchBar
          value={search}
          onChange={(val) => setSearch(val)}
          placeholder="Search by customer, agent, or order ID..."
        />
        <FilterToggle isOpen={showFilters} onToggle={handleToggleFilters} />
      </div>
      <div className="overflow-x-auto">
        <FilterBar
          fromDate={filters.from || ""}
          toDate={filters.to || ""}
          onFromDateChange={handleFromDateChange}
          onToDateChange={handleToDateChange}
          agents={agents}
          selectedAgent={filters.agent || "all"}
          onAgentChange={handleAgentChange}
          customers={customers}
          selectedCustomer={filters.customer || "all"}
          onCustomerChange={handleCustomerChange}
          isOpen={showFilters}
          onClear={handleClearFilters}
        />
      </div>
      <div className="pb-10">{renderContent()}</div>
    </div>
  );
}

export default function AdminHomePage() {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <AdminHomePageContent />
    </Suspense>
  );
}
