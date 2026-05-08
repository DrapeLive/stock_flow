"use client";
import StatusBadge from "@/components/ui/custom/StatusBadge";

interface OrderSummaryProps {
  customerName: string;
  agentName: string;
  orderDate: string;
  status: string;
  preferredTransport?: string;
  expectedDeliveryDate?: string;
  dispatchTransport?: string;
  lrNumber?: string;
}

function DeliverySummary({
  expectedDeliveryDate,
  preferredTransport,
  dispatchTransport,
  lrNumber,
}: {
  expectedDeliveryDate?: string;
  preferredTransport?: string;
  dispatchTransport?: string;
  lrNumber?: string;
}) {
  return (
    <div className="grid grid-cols-2 gap-y-4 gap-x-6">
      <div>
        <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">
          Expected Date of Delivery
        </p>
        <h3 className="text-sm font-semibold text-gray-800">
          {expectedDeliveryDate ? expectedDeliveryDate : "Not specified"}
        </h3>
      </div>

      <div>
        <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">
          Preferred Transport
        </p>
        <h3 className="text-sm font-semibold text-gray-800">
          {preferredTransport ? preferredTransport : "Not specified"}
        </h3>
      </div>
      {dispatchTransport && (
        <div>
          <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">
            Dispatch Transport
          </p>
          <h3 className="text-sm font-semibold text-gray-800">
            {dispatchTransport}
          </h3>
        </div>
      )}
      {lrNumber && (
        <div>
          <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">
            LR Number
          </p>
          <h3 className="text-sm font-semibold text-gray-800">{lrNumber}</h3>
        </div>
      )}
    </div>
  );
}

export default function OrderSummary({
  customerName,
  agentName,
  orderDate,
  status,
  preferredTransport,
  expectedDeliveryDate,
  dispatchTransport,
  lrNumber,
}: OrderSummaryProps) {
  return (
    <div className="flex flex-col bg-white border border-gray-100 rounded-2xl p-5 mb-6 shadow-[0_2px_10px_-4px_rgba(0,0,0,0.05)] gap-y-4">
      <h2 className="text-xl font-extrabold text-gray-900 mb-4">
        Order Summary
      </h2>
      <div className="grid grid-cols-2 gap-y-4 gap-x-6 border-b pb-4">
        <div>
          <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">
            Customer
          </p>
          <h3 className="text-sm font-semibold text-gray-800">
            {customerName}
          </h3>
        </div>
        <div>
          <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">
            Agent
          </p>
          <h3 className="text-sm font-semibold text-gray-800">{agentName}</h3>
        </div>
        <div>
          <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">
            Order Date
          </p>
          <h3 className="text-sm font-semibold text-gray-800">{orderDate}</h3>
        </div>
        <div>
          <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">
            Current Status
          </p>
          <StatusBadge status={status} />
        </div>
      </div>
      <DeliverySummary
        expectedDeliveryDate={expectedDeliveryDate}
        preferredTransport={preferredTransport}
        dispatchTransport={dispatchTransport}
        lrNumber={lrNumber}
      />
    </div>
  );
}
