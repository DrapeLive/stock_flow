"use client";
import { OrderItem as OrderItemType } from "@/types/order";
import OrderItem from "@/components/pages/admin/order-item/OrderItem";

interface OrderDetailItemsProps {
  items?: OrderItemType[];
}

export default function OrderDetailItems({ items }: OrderDetailItemsProps) {
  return (
    <>
      <div className="flex justify-between items-end mb-4 border-b border-gray-100 pb-2">
        <div>
          <h2 className="text-lg font-extrabold text-gray-900 leading-tight">Items</h2>
          <p className="text-xs text-gray-400 font-medium">Order items below</p>
        </div>
      </div>

      <div className="bg-white rounded-2xl overflow-hidden">
        <OrderItem items={items} />
      </div>
    </>
  );
}
