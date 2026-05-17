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
    <div className="flex flex-col items-center gap-5 w-full">
      {/* Delivery Info Row */}
      <div className="w-full grid grid-cols-2 gap-y-4 gap-x-6">
        <div className="flex flex-col gap-1">
          <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider">
            Expected Delivery
          </p>
          <h3 className="text-sm font-semibold text-gray-800">
            {expectedDeliveryDate || "Not specified"}
          </h3>
        </div>
        <div className="flex flex-col gap-1">
          <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider">
            Preferred Transport
          </p>
          <h3 className="text-sm font-semibold text-gray-800">
            {preferredTransport || "Not specified"}
          </h3>
        </div>
      </div>
      {/* Dispatch Card */}
      {(dispatchTransport || lrNumber) && (
        <div className="w-full rounded-2xl border border-primary/20 bg-primary/5 p-4 flex flex-col gap-4">
          {dispatchTransport && (
            <p className="text-[14px] text-gray-500 font-medium">
              Transported by{" "}
              <span className="text-[14px] font-semibold text-gray-800">
                {dispatchTransport}
              </span>
            </p>
          )}

          {dispatchTransport && lrNumber && (
            <div className="h-px bg-primary/10 w-full" />
          )}

          {lrNumber && (
            <button
              type="button"
              onClick={() => navigator.clipboard.writeText(lrNumber)}
              className="w-full rounded-xl bg-white border border-primary/15 px-4 py-4 flex flex-col items-center gap-1 transition-all hover:bg-primary/10 hover:border-primary/30 active:scale-[0.98] shadow-sm"
            >
              <p className="text-[10px] text-primary uppercase font-bold tracking-[0.2em]">
                LR Number
              </p>
              <h3 className="text-2xl font-extrabold tracking-wide text-gray-900 break-all leading-tight">
                {lrNumber}
              </h3>
              <p className="text-[10px] text-gray-400 font-medium flex items-center gap-1 mt-1">
                Tap to copy
              </p>
            </button>
          )}
        </div>
      )}{" "}
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
