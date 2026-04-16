"use client";
import { PackageCheck, Truck, CheckCircle2 } from "lucide-react";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";

interface OrderFooterProps {
  activeTab: string;
  status?: string;
  anyItemPacked: boolean;
  onUpdateStatus: (status: "PACKED" | "DISPATCHED") => void;
}

export default function OrderFooter({
  activeTab,
  status,
  anyItemPacked,
  onUpdateStatus,
}: OrderFooterProps) {
  const canDispatch = anyItemPacked && status !== "DISPATCHED";

  return (
    <div className="fixed bottom-6 left-0 right-0 px-4 max-w-4xl mx-auto flex justify-center mt-10">
      {activeTab === "Packing" && anyItemPacked && status === "PENDING" && (
        <StockFlowButton
          text="Complete Packing"
          icon={<PackageCheck />}
          onClick={() => onUpdateStatus("PACKED")}
          className="w-full sm:w-auto shadow-xl transform active:scale-95 transition-all text-white py-4 px-10 rounded-2xl"
        />
      )}

      {activeTab === "Dispatching" && canDispatch && (
        <StockFlowButton
          text="Confirm Dispatch"
          icon={<Truck />}
          onClick={() => onUpdateStatus("DISPATCHED")}
          className="w-full sm:w-auto shadow-xl transform active:scale-95 transition-all text-white py-4 px-10 rounded-2xl"
        />
      )}

      {activeTab === "Dispatching" && status === "DISPATCHED" && (
        <div className="bg-green-50 text-green-700 px-8 py-3 rounded-2xl border border-green-200 font-bold flex items-center gap-2">
          <CheckCircle2 size={20} />
          Order has been dispatched
        </div>
      )}
    </div>
  );
}
