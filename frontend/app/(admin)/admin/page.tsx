"use client";

import { useEffect, useState, Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { agentApi } from "@/lib/api/agents";
import Packed from "@/components/pages/admin/order_components/Packed";
import Pending from "@/components/pages/admin/order_components/Pending";
import Dispatched from "@/components/pages/admin/order_components/Dispatched";
import All from "@/components/pages/admin/order_components/All";
import FilterBar from "@/components/ui/FilterBar";
import FilterToggle from "@/components/ui/FilterToggle";
import { OrderFilters } from "@/components/pages/admin/order_components/types";

type Tab = "All" | "Packed" | "Pending" | "Dispatched";

interface SimpleAgent {
  id: number;
  username: string;
}

function AdminHomePageContent() {
  const searchParams = useSearchParams();
  const [activeTab, setActiveTab] = useState<Tab>("Pending");
  const [filters, setFilters] = useState<OrderFilters>({});
  const [agents, setAgents] = useState<SimpleAgent[]>([]);
  const [showFilters, setShowFilters] = useState(false);

  useEffect(() => {
    agentApi
      .getAll()
      .then((agents) => {
        setAgents(agents.map((a) => ({ id: a.id, username: a.user.username })));
      })
      .catch(console.error);
  }, []);

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

  const handleClearFilters = () => {
    setFilters({});
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
    const commonProps = { filters };
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

  return (
    <div className="min-h-screen min-w-full">
      <div className=" p-1.5 mt-2 flex items-center justify-between space-x-1 border border-gray-200 rounded-full mb-2">
        {(["All", "Pending", "Packed", "Dispatched"] as Tab[]).map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`flex-1 rounded-full py-2 font-bold text-xs transition-all duration-300 ${
              activeTab === tab
                ? "bg-primary text-white shadow-lg shadow-primary/20 ring-1 ring-primary/10"
                : "text-gray-500 hover:text-gray-700 hover:bg-gray-100/80"
            }`}
          >
            {tab}
          </button>
        ))}
      </div>
      <div className="flex justify-between items-center mb-4">
        <span className="text-gray-400 text-[10px] font-bold uppercase tracking-wider">
          Remaining Orders
        </span>
        <FilterToggle isOpen={showFilters} onToggle={handleToggleFilters} />
      </div>
      <FilterBar
        fromDate={filters.from || ""}
        toDate={filters.to || ""}
        onFromDateChange={handleFromDateChange}
        onToDateChange={handleToDateChange}
        agents={agents}
        selectedAgent={filters.agent || "all"}
        onAgentChange={handleAgentChange}
        isOpen={showFilters}
        onClear={handleClearFilters}
      />
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
