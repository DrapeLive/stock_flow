"use client";
import AgentsList from "@/components/pages/admin/users/AgentsList";
import CustomerList from "@/components/pages/admin/users/CustomersList";
import { useState } from "react";

type Tab = "Customers" | "Agents";

export default function CustomersPage() {
  const [activeTab, setActiveTab] = useState<Tab>("Customers");

  const renderContent = (): React.ReactNode => {
    if (activeTab == "Agents") {
      return <AgentsList />;
    } else if (activeTab == "Customers") {
      return <CustomerList />;
    }
  };
  return (
    <div className="min-h-screen min-w-full">
      <div className="border p-1 mt-2 flex items-center justify-center space-x-1 border-(--color-border) rounded-full">
        <button
          onClick={() => setActiveTab("Customers")}
          className={` rounded-full px-13.5 py-1 font-semibold text-xs ${activeTab == "Customers" ? "bg-(--color-primary) text-white" : "bg-white text-black"} `}
        >
          Customers
        </button>
        <button
          onClick={() => setActiveTab("Agents")}
          className={`bg-(--color-primary) rounded-full px-13.5 py-1 font-semibold text-xs ${activeTab == "Agents" ? "bg-(--color-primary) text-white" : "bg-white text-black"}`}
        >
          Agents
        </button>
      </div>
      <div>{renderContent()}</div>
    </div>
  );
}
