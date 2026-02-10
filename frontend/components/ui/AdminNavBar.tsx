"use client";

import { usePathname, useRouter } from "next/navigation";
import { Truck, Users, Archive } from "lucide-react";
import React from "react";

const AdminNavBar: React.FC = () => {
  const pathname = usePathname();
  const router = useRouter();
  return (
    <div className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full">
      <div className="bg-white py-4 flex gap-16 items-center justify-center shadow-[0_-6px_20px_rgba(0,0,0,0.1)]">
        <button
          onClick={() => router.push("/admin/users/customers")}
          className="flex flex-col items-center gap-1"
        >
          <Users
            size={24}
            className={
              pathname === "/admin/users/customers"
                ? "text-(--color-primary)"
                : "text-black"
            }
          />
          <span
            className={`text-[8px] ${
              pathname === "/admin/users/customers"
                ? "text-(--color-primary)"
                : "text-black"
            }`}
          >
            Manage Users
          </span>
        </button>

        <button
          onClick={() => router.push("/admin")}
          className="flex flex-col items-center gap-1"
        >
          <Truck
            size={26}
            className={
              pathname === "/admin" ? "text-(--color-primary)" : "text-black"
            }
          />
          <span
            className={`text-[8px] ${
              pathname === "/admin" ? "text-(--color-primary)" : "text-black"
            }`}
          >
            Orders
          </span>
        </button>

        <button
          onClick={() => router.push("/admin/items")}
          className="flex flex-col items-center gap-1"
        >
          <Archive
            size={27}
            className={
              pathname === "/admin/items"
                ? "text-(--color-primary)"
                : "text-black"
            }
          />
          <span
            className={`text-[8px] ${
              pathname === "/admin/items"
                ? "text-(--color-primary)"
                : "text-black"
            }`}
          >
            Stock
          </span>
        </button>
      </div>
    </div>
  );
};

export default AdminNavBar;
