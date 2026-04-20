"use client";

import { useEffect, useState } from "react";
import { agentApi } from "@/lib/api/agents";
import Packed from "@/components/pages/admin/order_components/Packed";
import Pending from "@/components/pages/admin/order_components/Pending";
import Dispatched from "@/components/pages/admin/order_components/Dispatched";
import All from "@/components/pages/admin/order_components/All";
import FilterBar from "@/components/ui/FilterBar";
import { OrderFilters } from "@/components/pages/admin/order_components/types";

type Tab = "All" | "Packed" | "Pending" | "Dispatched";

interface SimpleAgent {
  id: number;
  username: string;
}

export default function AdminHomePage() {
  const [activeTab, setActiveTab] = useState<Tab>("Pending");
  const [filters, setFilters] = useState<OrderFilters>({});
  const [agents, setAgents] = useState<SimpleAgent[]>([]);

  useEffect(() => {
    agentApi.getAll().then((agents) => {
      setAgents(agents.map((a) => ({ id: a.id, username: a.user.username })));
    }).catch(console.error);
  }, []);

  const handleFromDateChange = (date: string) => {
    setFilters((prev) => ({ ...prev, from: date || undefined }));
  };

  const handleToDateChange = (date: string) => {
    setFilters((prev) => ({ ...prev, to: date || undefined }));
  };

  const handleAgentChange = (agentId: string) => {
    setFilters((prev) => ({ ...prev, agent: agentId === "all" ? undefined : agentId }));
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
    <div className="min-h-screen min-w-full px-4">
      <div className="bg-gray-100/50 p-1.5 mt-2 flex items-center justify-between space-x-1 border border-gray-200 rounded-full mb-2">
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
      <FilterBar
        fromDate={filters.from || ""}
        toDate={filters.to || ""}
        onFromDateChange={handleFromDateChange}
        onToDateChange={handleToDateChange}
        agents={agents}
        selectedAgent={filters.agent || "all"}
        onAgentChange={handleAgentChange}
      />
      <div className="pb-10">{renderContent()}</div>
    </div>
  );
}
