"use client";
import OrderItem from "@/components/pages/admin/order-item/OrderItem";
import { customerApi } from "@/lib/api/customer";
import { toastError, toastSuccess } from "@/lib/toast";
import { CustomerResponse } from "@/types/customer";
import {
  ChevronLeft,
  Plus,
  User,
  ShoppingBag,
  Package,
  AlertTriangle,
  X,
} from "lucide-react";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { orderApi } from "@/lib/api/order";
import { OrderResponse, OutOfStockItem, PlaceOrderError } from "@/types/order";
import { PageLoading } from "@/components/ui/Loading";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { AxiosError } from "axios";
import { OrderTotals } from "@/components/order";

export default function OrderDetailsPage() {
  const params = useParams();
  const id = params.id as string;
  const router = useRouter();

  const [data, setData] = useState<CustomerResponse>();
  const [loading, setLoading] = useState(true);
  const [placingOrder, setPlacingOrder] = useState(false);
  const [orders, setOrders] = useState<OrderResponse>();
  const [loadError, setLoadError] = useState(false);
  const [showOutOfStockModal, setShowOutOfStockModal] = useState(false);
  const [outOfStockItems, setOutOfStockItems] = useState<OutOfStockItem[]>([]);

  const totalSets =
    orders?.items.reduce((sum, item) => sum + item.quantity, 0) || 0;

  const totalPieces =
    orders?.items.reduce(
      (sum, item) =>
        sum + item.quantity * (item.piece_count || 1),
      0,
    ) || 0;

  const totalMoney =
    orders?.items.reduce(
      (sum, item) =>
        sum +
        (Number(item.item_price) || 0) * item.quantity * (item.piece_count || 1),
      0,
    ) || 0;

  const handlePlaceOrder = async () => {
    const orderKey = localStorage.getItem("orderKey");
    if (!orderKey) return;

    setPlacingOrder(true);
    try {
      await orderApi.placeOrder(Number(orderKey));
      toastSuccess("Order placed successfully!");
      localStorage.removeItem("orderKey");
      router.push("/");
    } catch (error) {
      const axiosError = error as AxiosError<PlaceOrderError>;
      if (axiosError.response?.data?.out_of_stock_items) {
        setOutOfStockItems(axiosError.response.data.out_of_stock_items);
        setShowOutOfStockModal(true);
      } else {
        toastError(axiosError.response?.data?.error || "Failed to place order");
      }
    } finally {
      setPlacingOrder(false);
    }
  };

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const numericId = parseInt(id, 10);
        const response = await customerApi.getOne(numericId);
        setData(response);
        const key = localStorage.getItem("orderKey");
        if (key) {
          const res2 = await orderApi.getOne(Number(key));
          setOrders(res2);
        }
      } catch (e) {
        console.error("Error fetching order details:", e);
        setLoadError(true);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [id]);

  useEffect(() => {
    if (loadError) {
      toastError("Server Error");
      router.push(`/order/new/`);
    }
  }, [loadError, router]);

  if (loading) return <PageLoading />;

  return (
    <div className="min-h-screen bg-gray-50/50 pb-32">
      {/* Header */}
      <div className="bg-white border-b border-gray-100 px-6 py-6 sticky top-0 z-10">
        <div className="max-w-md mx-auto flex items-center justify-between">
          <div className="flex items-center gap-4">
            <button
              onClick={() => router.push("/order/new")}
              className="p-2 rounded-xl hover:bg-gray-50 text-gray-400 transition-colors"
            >
              <ChevronLeft size={20} />
            </button>
            <div className="flex flex-col">
              <h1 className="text-xl font-black text-gray-900 leading-tight">
                Order Details
              </h1>
              <p className="text-[10px] text-gray-400 font-bold uppercase tracking-wider">
                Step 2: Add Items
              </p>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-md mx-auto px-6 pt-8">
        {/* Customer Card */}
        <div className="bg-white p-5 rounded-3xl border border-gray-100 shadow-sm flex items-center gap-4 mb-8">
          <div className="w-12 h-12 rounded-2xl bg-primary/10 text-primary flex items-center justify-center border border-primary/5">
            <User size={24} />
          </div>
          <div>
            <p className="text-[10px] text-gray-400 uppercase font-black tracking-wider leading-none mb-1">
              Customer
            </p>
            <h3 className="text-lg font-bold text-gray-900 leading-tight">
              {data?.name}
            </h3>
            {data?.address && (
              <p className="text-xs text-gray-400 mt-0.5">{data.address}</p>
            )}
          </div>
        </div>

        {/* Items Section Header */}
        <div className="flex justify-between items-end mb-6">
          <div className="flex flex-col">
            <h2 className="text-xl font-black text-gray-900">Order Items</h2>
            <div className="flex gap-2 items-center mt-1">
              <span className="text-gray-400 text-[10px] font-bold uppercase tracking-wider">
                Selected
              </span>
              <div className="bg-amber-100 text-amber-600 rounded-full py-0.5 px-3 border border-amber-200">
                <span className="font-bold text-xs">
                  {orders?.items.length || 0}
                </span>
              </div>
            </div>
          </div>
          <StockFlowButton
            text="Add Item"
            variant="filled"
            icon={<Plus className="size-4" />}
            onClick={() => router.push(`/order/new/${id}/scanner`)}
            className="shadow-lg shadow-primary/20 ring-1 ring-primary/10 transition-all active:scale-95"
          />
        </div>

        {/* Items List */}
        <div className="space-y-4">
          {!orders || orders.items.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 bg-white rounded-3xl border border-dashed border-gray-200">
              <ShoppingBag size={48} className="text-gray-200 mb-4" />
              <p className="text-gray-400 font-bold">No items added yet</p>
              <p className="text-[10px] text-gray-300 uppercase tracking-widest mt-1">
                Scan QR codes to add products
              </p>
            </div>
          ) : (
            <div className="bg-white rounded-3xl border border-gray-100 overflow-hidden shadow-sm">
              <OrderItem
                orderId={orders.id}
                items={orders.items}
                isDelete={true}
              />
            </div>
          )}
        </div>

        {/* Order Totals */}
        {orders && orders.items.length > 0 && (
          <div className="mt-8">
            <OrderTotals
              totalSets={totalSets}
              totalPieces={totalPieces}
              totalPrice={totalMoney}
              onPlaceOrder={handlePlaceOrder}
              isLoading={placingOrder}
              buttonText="Place Order"
            />
          </div>
        )}

        {/* Out of Stock Modal */}
        {showOutOfStockModal && (
          <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-3xl max-w-sm w-full p-6 shadow-2xl">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-red-100 flex items-center justify-center">
                    <AlertTriangle className="text-red-500" size={20} />
                  </div>
                  <h3 className="text-lg font-black text-gray-900">
                    Out of Stock
                  </h3>
                </div>
                <button
                  onClick={() => setShowOutOfStockModal(false)}
                  className="p-2 hover:bg-gray-100 rounded-xl transition-colors"
                >
                  <X size={20} className="text-gray-400" />
                </button>
              </div>
              <p className="text-sm text-gray-500 mb-4">
                Some items are no longer available. Another agent may have
                placed an order.
              </p>
              <div className="space-y-3 mb-6 max-h-48 overflow-y-auto">
                {outOfStockItems.map((item, idx) => (
                  <div
                    key={idx}
                    className="bg-red-50 rounded-xl p-3 border border-red-100"
                  >
                    <p className="font-bold text-gray-900 text-sm">
                      {item.item_name}
                    </p>
                    <p className="text-xs text-gray-500 mt-1">
                      Size: {item.size_group} ({item.size})
                    </p>
                    <p className="text-xs text-gray-500">
                      Required: {item.required} | Available: {item.available}
                    </p>
                  </div>
                ))}
              </div>
              <div className="flex gap-3">
                <button
                  onClick={() => setShowOutOfStockModal(false)}
                  className="flex-1 py-3 rounded-xl border border-gray-200 text-gray-600 font-bold text-sm hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={() => setShowOutOfStockModal(false)}
                  className="flex-1 py-3 rounded-xl bg-primary text-white font-bold text-sm hover:opacity-90 transition-opacity"
                >
                  Remove Items
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
