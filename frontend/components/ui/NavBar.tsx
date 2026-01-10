"use client";

import { usePathname, useRouter } from "next/navigation";
import { Home, History, Settings, Plus } from "lucide-react";
import React from "react";

const NavBar: React.FC = () => {
  const pathname = usePathname();
  const router = useRouter();

  const isHome = pathname === "/";

  return (
    <div className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full">
      <div className="bg-white px-8 py-4 flex items-center justify-between shadow-[0_-6px_20px_rgba(0,0,0,0.1)]">
        
        <button
          onClick={() => router.push("/history")}
          className="flex flex-col items-center gap-1"
        >
          <History
            size={22}
            className={pathname === "/history" ? "text-(--color-primary)" : "text-black"}
          />
          <span
            className={`text-xs ${
              pathname === "/history" ? "text-(--color-primary)" : "text-black"
            }`}
          >
            History
          </span>
        </button>

        {isHome ? (
          <button
            onClick={() => router.push("/add")}
            className="bg-(--color-primary) text-white px-10 py-3 rounded-xl flex items-center justify-center"
          >
            <Plus size={26} />
          </button>
        ) : (
          <button
            onClick={() => router.push("/")}
            className="flex flex-col items-center gap-1"
          >
            <Home
              size={22}
              className={pathname === "/" ? "text-(--color-primary)" : "text-black"}
            />
            <span
              className={`text-xs ${
                pathname === "/" ? "text-(--color-primary)" : "text-black"
              }`}
            >
              Home
            </span>
          </button>
        )}

        <button
          onClick={() => router.push("/settings")}
          className="flex flex-col items-center gap-1"
        >
          <Settings
            size={22}
            className={
              pathname === "/settings" ? "text-(--color-primary)" : "text-black"
            }
          />
          <span
            className={`text-xs ${
              pathname === "/settings" ? "text-(--color-primary)" : "text-black"
            }`}
          >
            Settings
          </span>
        </button>
      </div>
    </div>
  );
};

export default NavBar;
