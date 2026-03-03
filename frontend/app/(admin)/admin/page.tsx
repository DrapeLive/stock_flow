"use client";

import { useState } from "react";
import Packed from "@/components/pages/admin/order_components/Packed";
import Pending from "@/components/pages/admin/order_components/Pending";
import Dispatched from "@/components/pages/admin/order_components/Dispatched";
import All from "@/components/pages/admin/order_components/All";

type Tab = "All" | "Packed" | "Pending" | "Dispatched";

export default function AdminHomePage() {
  const [activeTab, setActiveTab] = useState<Tab>("All");

  const renderContent = (): React.ReactNode => {
    switch (activeTab) {
      case "Packed":
        return <Packed />;
      case "Pending":
        return <Pending />;
      case "Dispatched":
        return <Dispatched />;
      default:
        return <All />;
    }
  };

  return (
    <div className="min-h-screen min-w-full px-4">
      <div className="bg-gray-100/50 p-1.5 mt-2 flex items-center justify-between space-x-1 border border-gray-200 rounded-full mb-6">
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
      <div className="pb-10">{renderContent()}</div>
    </div>
  );
}
