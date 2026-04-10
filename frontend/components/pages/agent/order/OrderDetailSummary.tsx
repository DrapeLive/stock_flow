"use client";
import StatusBadge from "@/components/ui/custom/StatusBadge";

interface OrderDetailSummaryProps {
  customerName: string;
  agentName: string;
  orderDate: string;
  status: string;
}

export default function OrderDetailSummary({
  customerName,
  agentName,
  orderDate,
  status,
}: OrderDetailSummaryProps) {
  return (
    <div className="bg-white border border-gray-100 rounded-2xl p-5 mb-6 shadow-[0_2px_10px_-4px_rgba(0,0,0,0.05)]">
      <h2 className="text-xl font-extrabold text-gray-900 mb-4">Order Summary</h2>
      <div className="grid grid-cols-2 gap-y-4 gap-x-6">
        <div>
          <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">Customer</p>
          <h3 className="text-sm font-semibold text-gray-800">{customerName}</h3>
        </div>
        <div>
          <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">Agent</p>
          <h3 className="text-sm font-semibold text-gray-800">{agentName}</h3>
        </div>
        <div>
          <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">Order Date</p>
          <h3 className="text-sm font-semibold text-gray-800">{orderDate}</h3>
        </div>
        <div>
          <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">Current Status</p>
          <StatusBadge status={status} />
        </div>
      </div>
    </div>
  );
}
