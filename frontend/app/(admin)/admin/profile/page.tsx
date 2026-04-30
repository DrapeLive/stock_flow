"use client";
import { useAuth } from "@/context/AuthContext";
import { LogOut, User, Mail, ShieldCheck, UserCircle, Building2 } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { authApi } from "@/lib/api/auth";
import { UserProfile } from "@/types/auth";

export default function Profile() {
  const { logout } = useAuth();
  const router = useRouter();
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchProfile = async () => {
      try {
        const data = await authApi.getProfile();
        setProfile(data);
      } catch (error) {
        console.error("Failed to fetch profile:", error);
      } finally {
        setLoading(false);
      }
    };
    fetchProfile();
  }, []);

  const handleLogout = () => {
    logout();
    router.push("/");
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50/50 py-10 px-6 flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
      </div>
    );
  }

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
            Account Management
          </p>
        </div>

        <div className="space-y-4">
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
            <div className="w-10 h-10 rounded-2xl bg-green-50 text-green-500 flex items-center justify-center">
              <ShieldCheck size={20} />
            </div>
            <div>
              <p className="text-[10px] text-gray-400 uppercase font-black tracking-wider leading-none mb-1">
                Access Level
              </p>
              <h3 className="text-base font-bold text-gray-800">
                {profile?.role || "N/A"}
              </h3>
            </div>
          </div>

          {profile?.business && (
            <div className="bg-white p-5 rounded-3xl border border-gray-100 shadow-sm flex items-center gap-4">
              <div className="w-10 h-10 rounded-2xl bg-amber-50 text-amber-500 flex items-center justify-center">
                <Building2 size={20} />
              </div>
              <div>
                <p className="text-[10px] text-gray-400 uppercase font-black tracking-wider leading-none mb-1">
                  Business
                </p>
                <h3 className="text-base font-bold text-gray-800 capitalize">
                  {profile.business}
                </h3>
              </div>
            </div>
          )}
        </div>

        <div className="mt-12 px-4">
          <button
            onClick={handleLogout}
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
