"use client";

import { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";
import { itemApi } from "@/lib/api/item";
import { ItemStockEntry, UIItem } from "@/types/item";
import { ItemList } from "@/components/items";

function normalizeAdminItem(item: ItemStockEntry): UIItem {
  return {
    id: item.id,
    name: item.name,
    type: item.type,
    price: item.price,
    variants: item.variants.map((v) => ({
      id: v.id,
      image: v.image,
      qr_code: v.qr_code,
      sizes: v.sizes,
    })),
  };
}
const ListItems: React.FC = () => {
  const { isAuthenticated } = useAuth();
  const router = useRouter();
  const [data, setData] = useState<UIItem[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchData = useCallback(async () => {
    try {
      const result = await itemApi.getStockList();
      setData(result.map(normalizeAdminItem));
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
    router.push(`/admin/items/qr-print?item=${id}`);
  };

  const handlePrintQR = (qr: string) => {
    router.push(`/admin/items/qr-print?qr=${qr}`);
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
