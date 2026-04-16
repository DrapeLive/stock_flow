"use client";

import { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";
import { itemApi } from "@/lib/api/item";
import { ItemStockEntry } from "@/types/item";
import { ItemList } from "@/components/items";

const ListItems: React.FC = () => {
  const { isAuthenticated } = useAuth();
  const router = useRouter();
  const [data, setData] = useState<ItemStockEntry[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchData = useCallback(async () => {
    try {
      const result = await itemApi.getStockList();
      setData(result);
    } catch (e) {
      console.error("Error fetching items:", e);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!isAuthenticated) return;

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
  }, [isAuthenticated, fetchData]);

  const handleEdit = (id: number) => {
    router.push(`/admin/items/edit/${id}`);
  };

  const handlePrintAll = (id: number) => {
    window.open(`/admin/items/qr-print/${id}`, "_blank");
  };

  const handlePrintQR = (qr: string) => {
    window.open(`/admin/items/qr/${qr}`, "_blank");
  };

  return (
    <ItemList
      items={data}
      loading={loading}
      context="admin"
      onAddItem={() => router.push("/admin/items/new")}
      onEdit={handleEdit}
      onPrintAll={handlePrintAll}
      onPrintQR={handlePrintQR}
    />
  );
};

export default ListItems;
