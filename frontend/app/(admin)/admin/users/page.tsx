"use client";
import AdminsList from "@/components/pages/admin/users/AdminsList";
import AgentsList from "@/components/pages/admin/users/AgentsList";
import CustomerList from "@/components/pages/admin/users/CustomersList";
import { useState } from "react";

type Tab = "Customers" | "Agents" | "Admins";

export default function CustomersPage() {
  const [activeTab, setActiveTab] = useState<Tab>(() => {
    if (typeof window !== "undefined") {
      return (
        (sessionStorage.getItem("adminUsersActiveTab") as Tab) || "Customers"
      );
    }
    return "Customers";
  });

  const handleTabChange = (tab: Tab) => {
    setActiveTab(tab);
    sessionStorage.setItem("adminUsersActiveTab", tab);
  };

  const renderContent = (): React.ReactNode => {
    if (activeTab == "Agents") {
      return <AgentsList />;
    } else if (activeTab == "Customers") {
      return <CustomerList />;
    } else if (activeTab == "Admins") {
      return <AdminsList />;
    }
  };
  return (
    <div className="min-h-screen min-w-full px-0">
      <div className="bg-gray-100/50 p-1.5 mt-2 flex items-center justify-between space-x-1 border border-gray-200 rounded-full mb-6">
        {(["Customers", "Agents", "Admins"] as Tab[]).map((tab) => (
          <button
            key={tab}
            onClick={() => handleTabChange(tab)}
            className={`flex-1 rounded-full py-2 font-bold text-xs transition-all duration-300 ${
              activeTab === tab
                ? "bg-primary text-white shadow-lg shadow-primary/20 ring-1 ring-primary/10"
                : "text-gray-400 hover:text-gray-600 hover:bg-gray-100/80"
            }`}
          >
            {tab}
          </button>
        ))}
      </div>
      <div className="pb-10">{renderContent()}</div>
    </div>
  );
}
