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
    <div className="min-h-screen min-w-full">
      <div className="border p-1 mt-2 flex items-center justify-between space-x-1 border-(--color-border) rounded-full">
        <button
          onClick={() => setActiveTab("All")}
          className={` rounded-full px-4 py-0.5 font-semibold text-xs ${activeTab == "All" ? "bg-(--color-primary) text-white" : "text-black bg-white"}`}
        >
          All
        </button>
        <button
          onClick={() => setActiveTab("Pending")}
          className={` rounded-full px-4 py-0.5  font-semibold text-xs ${activeTab == "Pending" ? "bg-(--color-primary) text-white" : "text-black bg-white"}`}
        >
          Pending
        </button>
        <button
          onClick={() => setActiveTab("Packed")}
          className={` rounded-full px-4 py-0.5 font-semibold text-xs ${activeTab == "Packed" ? "bg-(--color-primary) text-white" : "text-black bg-white"}`}
        >
          Packed
        </button>
        <button
          onClick={() => setActiveTab("Dispatched")}
          className={` rounded-full px-4 py-0.5 font-semibold text-xs ${activeTab == "Dispatched" ? "bg-(--color-primary) text-white" : "text-black bg-white"}`}
        >
          Dispatched
        </button>
      </div>
      <div>{renderContent()}</div>
    </div>
  );
}
