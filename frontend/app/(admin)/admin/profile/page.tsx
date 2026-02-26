"use client";
import { useAuth } from "@/context/AuthContext";
import { agentApi } from "@/lib/api/agents";
import { AgentResponse } from "@/types/agent";
import { ChevronRight, LogOut } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

export default function Profile() {
  const { isAuthenticated, user, logout } = useAuth();

  const [data, setData] = useState<AgentResponse>();
  const [loading, setLoading] = useState(true);

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await admin.getOne(user?.id);
        setData(response);
      } catch (error) {
        console.error("Error fetching data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [isAuthenticated, router, user]);

  if (loading) <h2 className="flex justify-center">Loading</h2>;

  return (
    <div className="min-h-screen min-w-full py-3 px-3">
      <div className="text-center">
        <h1>Profile</h1>
      </div>

      <div className="px-2">
        <button
          onClick={() => logout()}
          className="flex text-(--color-pending) justify-between items-center w-full"
        >
          <h3 className="text-(--color-pending)">Logout</h3>
          <LogOut className="w-5 h-5" />
        </button>
      </div>
    </div>
  );
}
