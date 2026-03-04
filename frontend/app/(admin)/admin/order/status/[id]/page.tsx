"use client";
import { ChevronLeft, PackageCheck, Truck, Package, CheckCircle2 } from "lucide-react";
import Link from "next/link";
import { useEffect, useState, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { orderApi } from "@/lib/api/order";
import { OrderResponse } from "@/types/order";
import OrderItem from "@/components/pages/admin/order-item/OrderItem";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import StatusBadge from "@/components/ui/custom/StatusBadge";

type Tab = "Packing" | "Dispatching";

export default function Page() {
  const params = useParams();
  const id = params.id as string;
  const router = useRouter();

  const [activeTab, setActiveTab] = useState<Tab>("Packing");
  const [loading, setLoading] = useState(false);
  const [data, setData] = useState<OrderResponse>();
  const [isPackingMode, setIsPackingMode] = useState(false);

  const fetchData = useCallback(async () => {
    try {
      const response = await orderApi.getOne(Number(id));
      setData(response);
    } catch (error) {
      console.error("Error fetching data:", error);
    }
  }, [id]);

  useEffect(() => {
    setLoading(true);
    fetchData().finally(() => setLoading(false));
  }, [fetchData]);

  const handlePackedChange = () => {
    // Refresh data to get updated packed_quantity from backend (or just rely on local state if trusted)
    fetchData();
  };

  const handleUpdateStatus = async (newStatus: "PACKED" | "DISPATCHED") => {
    try {
      setLoading(true);
      await orderApi.update(Number(id), { status: newStatus });
      await fetchData();
      if (newStatus === "PACKED") setIsPackingMode(false);
    } catch (err) {
      console.error("Error updating status:", err);
    } finally {
      setLoading(false);
    }
  };

  const allItemsPacked = data?.items.every(item => item.packed_quantity! >= item.quantity);

  if (loading && !data) return <h2 className="flex justify-center mt-10">Loading...</h2>;

  return (
    <div className="min-h-screen bg-white pb-20">
      {/* Header */}
      <div className="sticky top-0 z-40 bg-white/80 backdrop-blur-md border-b border-gray-100 px-4 py-3 flex items-center justify-between">
        <Link className="flex items-center text-primary font-medium hover:opacity-70 transition-opacity" href="/admin">
          <ChevronLeft size={20} className="mr-1" />
          <span>Back</span>
        </Link>
        <div className="text-sm font-bold text-gray-500 bg-gray-100 px-3 py-1 rounded-full">
          Order #{id}
        </div>
      </div>

      <div className="px-4 pt-4 max-w-4xl mx-auto">
        {/* Tabs */}
        <div className="bg-gray-100/50 p-1.5 flex items-center justify-center space-x-1 border border-gray-200 rounded-full mb-6">
          <button
            onClick={() => { setActiveTab("Packing"); setIsPackingMode(false); }}
            className={`flex-1 flex items-center justify-center gap-2 rounded-full py-2 font-bold text-xs transition-all ${activeTab == "Packing" ? "bg-primary text-white shadow-sm" : "text-gray-500 hover:text-gray-700"}`}
          >
            <Package size={14} />
            Packing
          </button>
          <button
            onClick={() => { setActiveTab("Dispatching"); setIsPackingMode(false); }}
            className={`flex-1 flex items-center justify-center gap-2 rounded-full py-2 font-bold text-xs transition-all ${activeTab == "Dispatching" ? "bg-primary text-white shadow-sm" : "text-gray-500 hover:text-gray-700"}`}
          >
            <Truck size={14} />
            Dispatching
          </button>
        </div>

        {/* Order Info Card */}
        <div className="bg-white border border-gray-100 rounded-2xl p-5 mb-6 shadow-[0_2px_10px_-4px_rgba(0,0,0,0.05)]">
          <h2 className="text-xl font-extrabold text-gray-900 mb-4">Order Summary</h2>
          <div className="grid grid-cols-2 gap-y-4 gap-x-6">
            <div>
              <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">Customer</p>
              <h3 className="text-sm font-semibold text-gray-800">{data?.customer_details.name}</h3>
            </div>
            <div>
              <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">Agent</p>
              <h3 className="text-sm font-semibold text-gray-800">{data?.agent_details.username}</h3>
            </div>
            <div>
              <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">Order Date</p>
              <h3 className="text-sm font-semibold text-gray-800">{data?.created_at?.slice(0, 10)}</h3>
            </div>
            <div>
              <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider mb-1">Current Status</p>
              <StatusBadge status={data?.status} />
            </div>
          </div>
        </div>

        {/* Action Header */}
        <div className="flex justify-between items-end mb-4 border-b border-gray-100 pb-2">
          <div>
            <h2 className="text-lg font-extrabold text-gray-900 leading-tight">Items to {activeTab}</h2>
            <p className="text-xs text-gray-400 font-medium">Manage order items below</p>
          </div>
          
          {activeTab == "Packing" && data?.status !== "DISPATCHED" && (
            <button
              onClick={() => setIsPackingMode(!isPackingMode)}
              className={`px-4 py-2 rounded-xl flex gap-2 items-center font-bold text-sm transition-all ${
                isPackingMode ? 'bg-green-600 text-white shadow-lg' : 'bg-primary text-white shadow-md'
              }`}
            >
              {isPackingMode ? (
                <>
                  <CheckCircle2 size={18} />
                  <span>Done Selecting</span>
                </>
              ) : (
                <>
                  <PackageCheck size={18} />
                  <span>Update Packing</span>
                </>
              )}
            </button>
          )}
        </div>

        {/* Item List */}
        <div className="bg-white rounded-2xl overflow-hidden">
          <OrderItem 
            items={data?.items} 
            isPacking={isPackingMode && activeTab === "Packing"} 
            onPackedChange={handlePackedChange}
          />
        </div>

        {/* Footer Actions */}
        <div className="fixed bottom-6 left-0 right-0 px-4 max-w-4xl mx-auto flex justify-center mt-10">
          {activeTab == "Packing" && allItemsPacked && data?.status === 'PENDING' && (
            <StockFlowButton 
              text="Mark as Fully Packed" 
              icon={<PackageCheck />} 
              onClick={() => handleUpdateStatus("PACKED")}
              className="w-full sm:w-auto shadow-xl transform active:scale-95 transition-all text-white py-4 px-10 rounded-2xl"
            />
          )}

          {activeTab == "Dispatching" && data?.status === "PACKED" && (
            <StockFlowButton 
              text="Confirm Dispatch" 
              icon={<Truck />} 
              onClick={() => handleUpdateStatus("DISPATCHED")}
              className="w-full sm:w-auto shadow-xl transform active:scale-95 transition-all text-white py-4 px-10 rounded-2xl"
            />
          )}
          
          {activeTab == "Dispatching" && data?.status === "DISPATCHED" && (
            <div className="bg-green-50 text-green-700 px-8 py-3 rounded-2xl border border-green-200 font-bold flex items-center gap-2">
              <CheckCircle2 size={20} />
              Order has been dispatched
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
