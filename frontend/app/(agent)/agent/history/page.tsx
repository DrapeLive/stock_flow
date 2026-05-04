"use client";

import AgentOrderList from "@/components/pages/agent/orderList/OrderList";

export default function History() {
  return (
    <div className="min-h-screen min-w-full px-4 bg-gray-50/30">
      <AgentOrderList pageOrderStatus="COMPLETED" />
    </div>
  );
}
