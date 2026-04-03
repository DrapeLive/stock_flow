"use client";

import { useAuth } from "@/context/AuthContext";
import { agentApi } from "@/lib/api/agents";
import { AssignedItem } from "@/types/agent";
import { PageLoading } from "@/components/ui/Loading";
import { ImagePreview } from "@/components/pages/ImagePreview";
import {
  Search,
  QrCode,
  ShoppingCart,
  Package,
  ChevronDown,
} from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import Image from "next/image";

export default function MyItemsPage() {
  const { user } = useAuth();
  const [items, setItems] = useState<AssignedItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [expandedItems, setExpandedItems] = useState<Set<number>>(new Set());
  const [expandedVariants, setExpandedVariants] = useState<Set<number>>(
    new Set(),
  );
  const router = useRouter();

  const toggleItemExpanded = (itemId: number) => {
    setExpandedItems((prev) => {
      const next = new Set(prev);
      if (next.has(itemId)) {
        next.delete(itemId);
      } else {
        next.add(itemId);
      }
      return next;
    });
  };

  const toggleVariantExpanded = (variantId: number) => {
    setExpandedVariants((prev) => {
      const next = new Set(prev);
      if (next.has(variantId)) {
        next.delete(variantId);
      } else {
        next.add(variantId);
      }
      return next;
    });
  };

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
            {filteredItems.map((item) => {
              const isItemExpanded = expandedItems.has(item.id);
              const firstImage = item.variants[0]?.image;

              return (
                <div
                  key={item.id}
                  className="bg-white border border-gray-100 rounded-2xl overflow-hidden hover:border-primary/30 hover:shadow-md transition-all"
                >
                  <div
                    className="flex items-center gap-4 p-4 active:scale-[0.98] transition-all cursor-pointer"
                    onClick={() => toggleItemExpanded(item.id)}
                  >
                    <div className="w-12 h-12 rounded-xl bg-primary/5 flex items-center justify-center border border-primary/10 flex-shrink-0 overflow-hidden">
                      {firstImage ? (
                        <ImagePreview src={firstImage} alt={item.name} />
                      ) : (
                        <Package size={20} className="text-primary" />
                      )}
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
                        <span className="text-xs font-bold text-gray-500">
                          {item.variants.length} colors
                        </span>
                        <span className="text-gray-200">•</span>
                        <span className="text-xs font-black text-primary">
                          ₹{item.price}
                        </span>
                      </div>
                    </div>

                    <div className="p-2 text-gray-400 transition-transform">
                      <ChevronDown
                        size={18}
                        className={`transition-transform ${isItemExpanded ? "rotate-180" : ""}`}
                      />
                    </div>
                  </div>

                  {isItemExpanded && item.variants.length > 0 && (
                    <div className="px-4 pb-4 border-t border-gray-50">
                      <div className="pt-4 space-y-8">
                        {item.variants.map((variant, idx) => {
                          const isVariantExpanded = expandedVariants.has(
                            variant.id,
                          );

                          return (
                            <div key={variant.id}>
                              <div className="flex items-center gap-3">
                                <div className="w-10 h-10 rounded-lg overflow-hidden bg-gray-50 border border-gray-100 flex-shrink-0">
                                  {variant.image ? (
                                    <ImagePreview
                                      src={variant.image}
                                      alt={`Variant ${idx + 1}`}
                                    />
                                  ) : (
                                    <div className="w-full h-full" />
                                  )}
                                </div>

                                <div className="flex-1">
                                  <span className="text-sm font-bold text-gray-900">
                                    Variant #{idx + 1}
                                  </span>
                                  <span className="text-[10px] text-gray-400 ml-2">
                                    {variant.size_ranges.length} size
                                    {variant.size_ranges.length !== 1
                                      ? "s"
                                      : ""}
                                  </span>
                                </div>

                                <button
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    handleQuickOrder();
                                  }}
                                  className="flex items-center gap-1.5 px-3 py-2 bg-primary text-white rounded-xl font-bold text-xs active:scale-95 transition-all"
                                >
                                  <ShoppingCart size={14} />
                                  Order
                                </button>

                                <button
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    toggleVariantExpanded(variant.id);
                                  }}
                                  className="p-2 text-gray-400 transition-transform active:scale-95"
                                >
                                  <ChevronDown
                                    size={16}
                                    className={`transition-transform ${isVariantExpanded ? "rotate-180" : ""}`}
                                  />
                                </button>
                              </div>

                              {isVariantExpanded &&
                                variant.size_ranges.length > 0 && (
                                  <div className="pb-2 space-y-1 mt-1">
                                    {variant.size_ranges.map((sr) => (
                                      <div
                                        key={sr.size_range}
                                        className="bg-gray-50 rounded-xl px-3 py-2 flex items-center justify-between"
                                      >
                                        <span className="text-xs font-bold text-gray-600">
                                          {sr.size_range}
                                        </span>
                                        <span
                                          className={`text-xs font-black ${sr.stock > 0 ? "text-green-600" : "text-red-500"}`}
                                        >
                                          {sr.stock} units
                                        </span>
                                      </div>
                                    ))}
                                  </div>
                                )}
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
