"use client";
import { useEffect, useState, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { orderApi } from "@/lib/api/order";
import { transportApi } from "@/lib/api/transport";
import { OrderResponse } from "@/types/order";
import OrderTabs, { Tab } from "@/components/pages/order/OrderTabs";
import OrderSummary from "@/components/pages/order/OrderSummary";
import OrderItemsSection from "@/components/pages/order/OrderItemsSection";
import OrderFooter from "@/components/pages/order/OrderFooter";
import OrderDetailHeader from "@/components/pages/admin/order-item/OrderDetailHeader";
import OrderLogs from "@/components/pages/order/OrderLogs";
import { toastSuccess, toastError } from "@/lib/toast";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { Trash2, Truck } from "lucide-react";

export default function Page() {
  const params = useParams();
  const id = params.id as string;
  const router = useRouter();

  const [activeTab, setActiveTab] = useState<Tab>("Packing");
  const [loading, setLoading] = useState(false);
  const [data, setData] = useState<OrderResponse>();
  const [isPackingMode, setIsPackingMode] = useState(false);
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
  const [showDispatchDialog, setShowDispatchDialog] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [dispatchTransport, setDispatchTransport] = useState<string>("");
  const [lrNumber, setLrNumber] = useState<string>("");
  const [transports, setTransports] = useState<
    { value: string; label: string }[]
  >([]);

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

    const fetchTransports = async () => {
      try {
        const response = await transportApi.getActive();
        const formattedTransports = response.map((transport) => ({
          value: transport.id.toString(),
          label: transport.name,
        }));
        setTransports(formattedTransports);
      } catch (error) {
        console.error("Error fetching transports:", error);
      }
    };

    fetchTransports();
  }, [fetchData]);

  const handlePackedChange = () => {
    fetchData();
  };

  const handleUpdateStatus = async (newStatus: "PACKED" | "DISPATCHED") => {
    if (newStatus === "DISPATCHED" && isPartiallyPacked) {
      setShowDispatchDialog(true);
      return;
    }
    await updateStatus(newStatus);
  };

  const updateStatus = async (newStatus: "PACKED" | "DISPATCHED") => {
    try {
      setLoading(true);
      if (newStatus === "DISPATCHED") {
        await orderApi.dispatchOrder(Number(id));
      } else {
        await orderApi.update(Number(id), { status: newStatus });
      }
      await fetchData();
      if (newStatus === "PACKED") setIsPackingMode(false);
    } catch (err) {
      console.error("Error updating status:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleConfirmDispatch = async () => {
    setShowDispatchDialog(false);
    try {
      await orderApi.dispatchOrder(Number(id), {
        transport_company: dispatchTransport
          ? parseInt(dispatchTransport)
          : null,
        lr_number: lrNumber,
      });
      await fetchData();
    } catch (err) {
      console.error("Error dispatching order:", err);
    }
  };

  const handleTabChange = (tab: Tab) => {
    setActiveTab(tab);
    setIsPackingMode(false);
  };

  const handleDeleteOrder = async () => {
    if (!id) return;
    setDeleting(true);
    try {
      await orderApi.delete(Number(id));
      toastSuccess("Order deleted successfully");
      router.push("/admin");
    } catch (err) {
      toastError("Failed to delete order");
      console.error(err);
    } finally {
      setDeleting(false);
      setShowDeleteDialog(false);
    }
  };

  const anyItemPacked = data?.items.some(
    (item) => (item.packed_quantity ?? 0) > 0,
  );

  const allItemsPacked = data?.items.every(
    (item) => (item.packed_quantity ?? 0) >= item.quantity,
  );

  const isPartiallyPacked = anyItemPacked && !allItemsPacked;

  const isDeletable = data?.status === "PENDING" || data?.status === "PACKED";

  if (loading && !data)
    return <h2 className="flex justify-center mt-10">Loading...</h2>;

  return (
    <div className="min-h-screen bg-white pb-20">
      <OrderDetailHeader orderId={id} backHref="/admin" />

      <div className="px-4 pt-4 max-w-4xl mx-auto">
        <OrderTabs activeTab={activeTab} onTabChange={handleTabChange} />

        <OrderSummary
          customerName={data?.customer_details.name ?? ""}
          agentName={data?.agent_details.username ?? ""}
          orderDate={data?.created_at?.slice(0, 10) ?? ""}
          status={data?.status ?? ""}
          preferredTransport={data?.preferred_transport_name ?? ""}
          expectedDeliveryDate={data?.expected_delivery_date ?? ""}
          dispatchTransport={
            transports.find(
              (transport) => Number(transport.value) == data?.transport_company,
            )?.label ?? ""
          }
          lrNumber={data?.lr_number ?? ""}
        />

        <OrderItemsSection
          items={data?.items}
          activeTab={activeTab}
          isPackingMode={isPackingMode}
          onPackedChange={handlePackedChange}
          onTogglePackingMode={() => setIsPackingMode(!isPackingMode)}
          status={data?.status}
          orderId={Number(id)}
        />

        {isDeletable && (
          <div className="mt-6 pt-4 border-t border-gray-100">
            <StockFlowButton
              text="Delete Order"
              icon={<Trash2 />}
              onClick={() => setShowDeleteDialog(true)}
              variant="outline"
              className="w-full shadow-lg border-red-200 text-red-500 hover:bg-red-500 hover:text-white"
            />
          </div>
        )}

        <OrderLogs orderId={Number(id)} />
      </div>

      <OrderFooter
        activeTab={activeTab}
        status={data?.status}
        anyItemPacked={anyItemPacked!}
        onUpdateStatus={handleUpdateStatus}
      />

      {showDeleteDialog && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl p-6 max-w-sm w-full shadow-xl">
            <h3 className="text-lg font-bold text-gray-900 mb-2">
              Delete Order?
            </h3>
            <p className="text-sm text-gray-500 mb-6">
              This will return the stock back to the warehouse. This action
              cannot be undone.
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setShowDeleteDialog(false)}
                className="flex-1 py-3 px-4 rounded-xl border border-gray-200 text-gray-700 font-medium hover:bg-gray-50 transition-colors"
                disabled={deleting}
              >
                Cancel
              </button>
              <button
                onClick={handleDeleteOrder}
                disabled={deleting}
                className="flex-1 py-3 px-4 rounded-xl bg-red-500 text-white font-medium hover:bg-red-600 transition-colors disabled:opacity-50"
              >
                {deleting ? "Deleting..." : "Delete"}
              </button>
            </div>
          </div>
        </div>
      )}

      {showDispatchDialog && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl p-6 max-w-sm w-full shadow-xl">
            <h3 className="text-lg font-bold text-gray-900 mb-2">
              Dispatch Order
            </h3>
            <p className="text-sm text-gray-500 mb-4">
              Unpacked items will be returned to the warehouse.
            </p>

            <div className="space-y-4 mb-6">
              <div>
                <label className="text-xs font-bold uppercase tracking-widest text-gray-400 mb-1.5 block">
                  Transport Company
                </label>
                <select
                  value={dispatchTransport}
                  onChange={(e) => setDispatchTransport(e.target.value)}
                  className="w-full px-4 py-3 bg-gray-50 border border-gray-100 rounded-xl focus:border-primary focus:ring-2 focus:ring-primary/10 text-sm"
                >
                  <option value="">Select Transport</option>
                  {transports.map((t) => (
                    <option key={t.value} value={t.value}>
                      {t.label}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-xs font-bold uppercase tracking-widest text-gray-400 mb-1.5 block">
                  LR Number
                </label>
                <input
                  type="text"
                  value={lrNumber}
                  onChange={(e) => setLrNumber(e.target.value)}
                  placeholder="Enter LR number"
                  className="w-full px-4 py-3 bg-gray-50 border border-gray-100 rounded-xl focus:border-primary focus:ring-2 focus:ring-primary/10 text-sm"
                />
              </div>
            </div>

            <div className="flex gap-3">
              <button
                onClick={() => setShowDispatchDialog(false)}
                className="flex-1 py-3 px-4 rounded-xl border border-gray-200 text-gray-700 font-medium hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleConfirmDispatch}
                className="flex-1 py-3 px-4 rounded-xl bg-primary text-white font-medium hover:bg-primary/90 transition-colors"
              >
                Dispatch
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
