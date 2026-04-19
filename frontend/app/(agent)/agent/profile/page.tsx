"use client";
import { PageLoading } from "@/components/ui/Loading";
import { useAuth } from "@/context/AuthContext";
import { agentApi } from "@/lib/api/agents";
import { authApi } from "@/lib/api/auth";
import { toastSuccess } from "@/lib/toast";
import { AgentResponse } from "@/types/agent";
import { UserProfile } from "@/types/auth";
import {
  ChevronRight,
  LogOut,
  User,
  Mail,
  ShieldCheck,
  UserCircle,
  Phone,
} from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

export default function Profile() {
  const { user, logout } = useAuth();

  const [data, setData] = useState<AgentResponse>();
  const [profile, setProfile] = useState<UserProfile>();
  const [loading, setLoading] = useState(true);

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      if (!user?.id) return;
      try {
        const [agentData, profileData] = await Promise.all([
          agentApi.getProfile(user.id),
          authApi.getProfile(),
        ]);
        setData(agentData);
        setProfile(profileData);
      } catch (e) {
        console.error("Error fetching agent data:", e);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [user]);

  if (loading) return <PageLoading />;

  return (
    <div className="min-h-screen bg-gray-50/50 py-10 px-6">
      <div className="max-w-md mx-auto">
        <div className="text-center mb-10">
          <div className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-primary/10 text-primary mb-4 shadow-sm border border-primary/5">
            <UserCircle size={48} />
          </div>
          <h1 className="text-2xl font-black text-gray-900 leading-tight">
            Your Profile
          </h1>
          <p className="text-xs text-gray-400 font-bold uppercase tracking-widest mt-1">
            Agent Dashboard
          </p>
        </div>

        <div className="space-y-4 pb-10">
          <div className="bg-white p-5 rounded-3xl border border-gray-100 shadow-sm flex items-center gap-4">
            <div className="w-10 h-10 rounded-2xl bg-blue-50 text-blue-500 flex items-center justify-center">
              <User size={20} />
            </div>
            <div>
              <p className="text-[10px] text-gray-400 uppercase font-black tracking-wider leading-none mb-1">
                Username
              </p>
              <h3 className="text-base font-bold text-gray-800">
                {profile?.username || "N/A"}
              </h3>
            </div>
          </div>

          <div className="bg-white p-5 rounded-3xl border border-gray-100 shadow-sm flex items-center gap-4">
            <div className="w-10 h-10 rounded-2xl bg-purple-50 text-purple-500 flex items-center justify-center">
              <Mail size={20} />
            </div>
            <div>
              <p className="text-[10px] text-gray-400 uppercase font-black tracking-wider leading-none mb-1">
                Email Address
              </p>
              <h3 className="text-base font-bold text-gray-800">
                {profile?.email || "N/A"}
              </h3>
            </div>
          </div>

          <div className="bg-white p-5 rounded-3xl border border-gray-100 shadow-sm flex items-center gap-4">
            <div className="w-10 h-10 rounded-2xl bg-amber-50 text-amber-500 flex items-center justify-center">
              <Phone size={20} />
            </div>
            <div>
              <p className="text-[10px] text-gray-400 uppercase font-black tracking-wider leading-none mb-1">
                Contact
              </p>
              <h3 className="text-base font-bold text-gray-800">
                +91 {data?.contact || "N/A"}
              </h3>
            </div>
          </div>

          <div className="bg-white p-5 rounded-3xl border border-gray-100 shadow-sm flex items-center gap-4">
            <div className="w-10 h-10 rounded-2xl bg-green-50 text-green-500 flex items-center justify-center">
              <ShieldCheck size={20} />
            </div>
            <div>
              <p className="text-[10px] text-gray-400 uppercase font-black tracking-wider leading-none mb-1">
                Account Role
              </p>
              <h3 className="text-base font-bold text-gray-800">
                {profile?.role || "N/A"}
              </h3>
            </div>
          </div>

          <div className="bg-white px-5 py-4 rounded-3xl border border-gray-100 shadow-sm">
            <button
              onClick={() => router.push("/agent/customers/")}
              className="flex justify-between items-center w-full py-2 group"
            >
              <div className="flex items-center gap-4">
                <div className="w-8 h-8 rounded-xl bg-gray-50 text-gray-400 flex items-center justify-center group-hover:bg-primary/10 group-hover:text-primary transition-colors">
                  <User size={16} />
                </div>
                <h3 className="text-sm font-bold text-gray-700">
                  My Customers
                </h3>
              </div>
              <div className="flex items-center gap-1">
                <span className="text-sm font-black text-primary bg-primary/5 px-2 py-0.5 rounded-lg">
                  {data?.total_customers || 0}
                </span>
                <ChevronRight
                  size={18}
                  className="text-gray-300 group-hover:text-primary transition-colors"
                />
              </div>
            </button>
          </div>
        </div>

        <div className="mt-8 px-4 flex flex-col gap-4">
          <button
            onClick={() => {
              logout();
              toastSuccess("Successfully logged out");
              router.push("/");
            }}
            className="flex items-center justify-center gap-3 w-full bg-white text-rose-500 font-black py-4 rounded-3xl border border-rose-100 shadow-md hover:bg-rose-50 transition-all transform active:scale-95"
          >
            <span>Sign Out</span>
            <LogOut size={20} />
          </button>
        </div>
      </div>
    </div>
  );
}
