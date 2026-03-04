"use client";

import { usePathname, useRouter } from "next/navigation";
import { Home, History, Settings, Plus } from "lucide-react";
import React from "react";

const NavBar: React.FC = () => {
  const pathname = usePathname();
  const router = useRouter();

  const isHome = pathname === "/";

  const navItems = [
    {
      label: "History",
      icon: History,
      path: "/history",
    },
    {
      label: "Profile",
      icon: Settings,
      path: "/profile",
    },
  ];

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 flex justify-center pointer-events-none pb-[env(safe-area-inset-bottom,1.5rem)] mb-4">
      <div className="bg-white/70 backdrop-blur-2xl border border-white/40 w-[calc(100%-2rem)] max-w-md pointer-events-auto py-2.5 px-6 flex items-center justify-between shadow-[0_20px_50px_-12px_rgba(0,0,0,0.2)] rounded-[2rem] mx-auto transition-all duration-500">

        {/* History */}
        <button
          onClick={() => router.push("/history")}
          className={`flex flex-col items-center justify-center flex-1 h-14 relative group active:scale-90 ${
            pathname === "/history"
              ? "bg-primary text-white shadow-lg rounded-[2rem]"
              : "text-gray-400 hover:text-gray-600"
          }`}
        >
          <div className="p-2 rounded-xl transition-all duration-300">
            <History
              size={pathname === "/history" ? 20 : 18}
              strokeWidth={pathname === "/history" ? 2.5 : 2}
            />
          </div>
          <span
            className={`text-[8px] font-black uppercase tracking-[0.15em] transition-all duration-300 mt-1 ${
              pathname === "/history" ? "opacity-100" : "opacity-60"
            }`}
          >
            History
          </span>
        </button>

        {/* Center — New Order (on home) or Home (elsewhere) */}
        {isHome ? (
          <button
            onClick={() => router.push("/order/new")}
            className="flex flex-col items-center justify-center flex-1 h-14 bg-[var(--color-primary)] text-white shadow-lg rounded-[2rem] active:scale-90 transition-all duration-300"
          >
            <Plus size={20} strokeWidth={2.5} />
            <span className="text-[8px] font-black uppercase tracking-[0.15em] mt-1">
              New Order
            </span>
          </button>
        ) : (
          <button
            onClick={() => router.push("/")}
            className={`flex flex-col items-center justify-center flex-1 h-14 relative group active:scale-90 ${
              pathname === "/"
                ? "bg-primary text-white shadow-lg rounded-[2rem]"
                : "text-gray-400 hover:text-gray-600"
            }`}
          >
            <div className="p-2 rounded-xl transition-all duration-300">
              <Home
                size={pathname === "/" ? 20 : 18}
                strokeWidth={pathname === "/" ? 2.5 : 2}
              />
            </div>
            <span
              className={`text-[8px] font-black uppercase tracking-[0.15em] transition-all duration-300 mt-1 ${
                pathname === "/" ? "opacity-100" : "opacity-60"
              }`}
            >
              Orders
            </span>
          </button>
        )}

        {/* Profile / Settings */}
        <button
          onClick={() => router.push("/profile")}
          className={`flex flex-col items-center justify-center flex-1 h-14 relative group active:scale-90 ${
            pathname === "/profile"
              ? "bg-primary text-white shadow-lg rounded-[2rem]"
              : "text-gray-400 hover:text-gray-600"
          }`}
        >
          <div className="p-2 rounded-xl transition-all duration-300">
            <Settings
              size={pathname === "/profile" ? 20 : 18}
              strokeWidth={pathname === "/profile" ? 2.5 : 2}
            />
          </div>
          <span
            className={`text-[8px] font-black uppercase tracking-[0.15em] transition-all duration-300 mt-1 ${
              pathname === "/profile" ? "opacity-100" : "opacity-60"
            }`}
          >
            Profile
          </span>
        </button>
      </div>
    </div>
  );
};

export default NavBar;
