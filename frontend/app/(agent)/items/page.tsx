"use client";

import { useAuth } from "@/context/AuthContext";
import { agentApi } from "@/lib/api/agents";
import { AssignedItem } from "@/types/agent";
import { PageLoading } from "@/components/ui/Loading";
import { Search, QrCode, ShoppingCart, Package, Info } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

export default function MyItemsPage() {
  const { user } = useAuth();
  const [items, setItems] = useState<AssignedItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const router = useRouter();

  useEffect(() => {
    const fetchData = async () => {
      if (!user?.id) return;
      try {
        const agent = await agentApi.getProfile(user.id);
        setItems(agent.assigned_items || []);
      } catch (error) {
        console.error("Error fetching items:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [user]);

  const filteredItems = items.filter((item) =>
    item.name.toLowerCase().includes(searchQuery.toLowerCase()),
  );

  const handleScanQR = () => {
    router.push("/items/scanner");
  };

  const handleQuickOrder = () => {
    router.push("/order/new");
  };

  if (loading) return <PageLoading />;

  return (
    <div className="min-h-screen bg-gray-50/50 pb-20">
      <div className="bg-white border-b border-gray-100 px-6 py-6 sticky top-0 z-10">
        <div className="max-w-md mx-auto">
          <div className="flex flex-col">
            <h1 className="text-xl font-black text-gray-900 leading-tight">
              My Items
            </h1>
            <div className="flex gap-2 items-center mt-1">
              <span className="text-gray-400 text-[10px] font-bold uppercase tracking-wider">
                Available to Order
              </span>
              <div className="bg-primary/10 text-primary rounded-full py-0.5 px-3 border border-primary/20">
                <span className="font-bold text-xs">{items.length}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-md mx-auto px-6 pt-6">
        <button
          onClick={handleScanQR}
          className="w-full mb-6 flex items-center justify-center gap-3 bg-linear-to-r from-primary to-primary/80 text-white py-4 px-6 rounded-2xl shadow-lg shadow-primary/25 active:scale-[0.98] transition-all"
        >
          <QrCode size={22} strokeWidth={2.5} />
          <span className="font-bold text-sm">Scan QR to Check Price</span>
        </button>

        <div className="relative mb-6">
          <Search
            size={18}
            className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400"
          />
          <input
            type="text"
            placeholder="Search assigned items..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-11 pr-4 py-3.5 bg-white border border-gray-100 rounded-2xl font-bold text-gray-900 placeholder:text-gray-300 focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all"
          />
        </div>

        {items.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-gray-300">
            <Package size={48} className="mb-4 opacity-20" />
            <h2 className="text-lg font-bold text-gray-800">
              No Items Assigned
            </h2>
            <p className="text-sm text-gray-400 mt-1 text-center max-w-[200px]">
              Contact admin to assign items to your account.
            </p>
          </div>
        ) : filteredItems.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-gray-300">
            <Search size={40} className="mb-4 opacity-20" />
            <h2 className="text-lg font-bold text-gray-800">No Results</h2>
            <p className="text-sm text-gray-400 mt-1">
              No items match "{searchQuery}"
            </p>
          </div>
        ) : (
          <div className="space-y-3 pb-10">
            {filteredItems.map((item) => (
              <div
                key={item.id}
                className="flex items-center gap-4 bg-white border border-gray-100 p-4 hover:border-primary/30 hover:shadow-md transition-all rounded-2xl group active:scale-[0.98]"
              >
                <div className="w-12 h-12 rounded-xl bg-primary/5 flex items-center justify-center border border-primary/10 flex-shrink-0">
                  <Package size={20} className="text-primary" />
                </div>

                <div className="flex-1 min-w-0">
                  <h6 className="font-bold text-gray-900 text-base truncate leading-tight">
                    {item.name}
                  </h6>
                  <div className="flex items-center gap-2 mt-1">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-gray-400">
                      {item.type}
                    </span>
                    <span className="text-gray-200">•</span>
                    <span className="text-xs font-black text-primary">
                      ₹{item.price}
                    </span>
                  </div>
                </div>

                <button
                  onClick={handleQuickOrder}
                  className="flex items-center gap-1.5 px-3 py-2 bg-primary text-white rounded-xl font-bold text-xs active:scale-95 transition-all"
                >
                  <ShoppingCart size={14} />
                  Order
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
