"use client";

import { usePathname, useRouter } from "next/navigation";
import { Truck, Users, Archive, BarChart3, Store } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import React from "react";

const AdminNavBar: React.FC = () => {
  const pathname = usePathname();
  const router = useRouter();
  const { isSuperuser } = useAuth();

  const navItems = [
    {
      label: "Users",
      icon: Users,
      path: "/admin/users",
      size: 20,
    },
    {
      label: "Orders",
      icon: Truck,
      path: "/admin",
      size: 22,
    },
    {
      label: "Stats",
      icon: BarChart3,
      path: "/admin/analytics",
      size: 20,
    },
    {
      label: "Stock",
      icon: Archive,
      path: "/admin/items",
      size: 22,
    },
  ];

  if (isSuperuser) {
    navItems.splice(2, 0, {
      label: "Brands",
      icon: Store,
      path: "/admin/brands",
      size: 18,
    });
  }

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 flex justify-center pointer-events-none pb-[env(safe-area-inset-bottom,1.5rem)] mb-4">
      <div className="bg-white/70 backdrop-blur-2xl border border-white/40 w-[calc(100%-2rem)] max-w-md pointer-events-auto py-2.5 px-4 flex items-center justify-between shadow-[0_20px_50px_-12px_rgba(0,0,0,0.2)] rounded-[2rem] mx-auto transition-all duration-500">
        {navItems.map((item) => {
          const isActive =
            pathname === item.path ||
            (item.path !== "/admin" && pathname.startsWith(item.path));

          return (
            <button
              key={item.path}
              onClick={() => router.push(item.path)}
              className={`flex flex-col items-center justify-center flex-1 h-14 relative group active:scale-90 ${isActive ? "bg-primary text-white shadow-lg rounded-[2rem]" : "text-gray-400 hover:text-gray-600"}`}
            >
              <div
                className={`
                p-2 rounded-xl transition-all duration-300

              `}
              >
                <item.icon
                  size={isActive ? 20 : 18}
                  strokeWidth={isActive ? 2.5 : 2}
                />
              </div>
              <span
                className={`
                text-[8px] font-black uppercase tracking-[0.15em] transition-all duration-300 mt-1
                ${isActive ? "opacity-100" : "opacity-60"}
              `}
              >
                {item.label}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
};

export default AdminNavBar;
