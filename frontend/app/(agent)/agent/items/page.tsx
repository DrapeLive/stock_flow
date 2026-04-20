"use client";

import { useAuth } from "@/context/AuthContext";
import { agentApi } from "@/lib/api/agents";
import { AssignedItem } from "@/types/agent";
import { PageLoading } from "@/components/ui/Loading";
import { useRouter } from "next/navigation";
import { useEffect, useState, useCallback } from "react";
import { ItemList } from "@/components/items";
import { ItemType, UIItem } from "@/types/item";

function normalizeAgentItem(item: AssignedItem): UIItem {
  return {
    id: item.id,
    name: item.name,
    type: item.type as ItemType,
    price: item.price,
    variants: item.variants.map((v) => ({
      id: v.id,
      image: v.image,
      qr_code: v.qr_code,
      sizes: v.size_ranges.map((sr) => ({
        size: sr.size_range,
        stock: sr.stock,
      })),
    })),
  };
}

export default function MyItemsPage() {
  const { user } = useAuth();
  const [items, setItems] = useState<UIItem[]>([]);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  const fetchData = useCallback(async () => {
    if (!user?.id) return;
    setLoading(true);
    try {
      const agent = await agentApi.getProfile(user.id);
      setItems((agent.assigned_items || []).map(normalizeAgentItem));
    } catch (error) {
      console.error("Error fetching items:", error);
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    if (!user?.id) return;

    fetchData();

    const handleFocus = () => {
      fetchData();
    };

    window.addEventListener("focus", handleFocus);

    const interval = setInterval(fetchData, 30000);

    return () => {
      window.removeEventListener("focus", handleFocus);
      clearInterval(interval);
    };
  }, [user, fetchData]);

  const handleOrder = () => {
    router.push("/agent/order/new");
  };

  const handlePriceCheck = () => {
    router.push("/agent/items/scanner");
  };

  if (loading) return <PageLoading />;

  return (
    <ItemList
      items={items}
      loading={loading}
      context="agent"
      onOrder={handleOrder}
      onPriceCheck={handlePriceCheck}
    />
  );
}
