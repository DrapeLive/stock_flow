"use client";

import { useAuth } from "@/context/AuthContext";
import { agentApi } from "@/lib/api/agents";
import { AssignedItem } from "@/types/agent";
import { PageLoading } from "@/components/ui/Loading";
import { useRouter } from "next/navigation";
import { useEffect, useState, useCallback } from "react";
import { ItemList } from "@/components/items";

export default function MyItemsPage() {
  const { user } = useAuth();
  const [items, setItems] = useState<AssignedItem[]>([]);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  const fetchData = useCallback(async () => {
    if (!user?.id) return;
    setLoading(true);
    try {
      const agent = await agentApi.getProfile(user.id);
      setItems(agent.assigned_items || []);
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
    router.push("/order/new");
  };

  if (loading) return <PageLoading />;

  return (
    <ItemList
      items={items}
      loading={loading}
      context="agent"
      onOrder={handleOrder}
    />
  );
}
