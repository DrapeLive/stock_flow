"use client";
import { AlertDestructive } from "@/components/ui/AlertDestructive";
import { PageLoading } from "@/components/ui/Loading";
import { SuccessAlert } from "@/components/ui/SuccessAlert";
import { useAuth } from "@/context/AuthContext";
import { agentApi } from "@/lib/api/agents";
import { AgentResponse } from "@/types/agent";
import { ChevronRight, LogOut } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

export default function Profile() {
  const { user, logout } = useAuth();

  const [data, setData] = useState<AgentResponse>();
  const [loading, setLoading] = useState(true);
  const [success, setSuccess] = useState(false);

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await agentApi.getOne(user!.id);
        setData(response);
      } catch (e) {
        <AlertDestructive heading="Error" description={"Server Not Found"} />;
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [user]);

  if (loading) <PageLoading />;

  if (success) {
    return (
      <SuccessAlert
        title="Success"
        description="Successfully Logout"
        onClose={() => router.push("/profile")}
      />
    );
  }

  return (
    <div className="min-h-screen min-w-full py-3 px-3">
      <div className="text-center">
        <h1>Profile</h1>
      </div>
      {/*<div className="flex justify-center items-center pb-6">
                <User className="w-45 h-45 bg-(--color-border) rounded-full"/>
            </div>*/}
      <div className="flex flex-col items-center gap-1.5 pb-10">
        <h3>{data?.user.username}</h3>
        <h3 className="text-(--color-text)">{data?.user.email}</h3>
        <h3 className="text-(--color-text)">+91 {data?.contact}</h3>
      </div>
      <div className="px-2">
        <button className="flex justify-between items-center pb-2 w-full">
          <h3>Customers</h3>
          <div className="flex items-center justify-center gap-1">
            <h3 className="leading-none m-0">{data?.total_customers}</h3>
            <ChevronRight className="w-5 h-5" />
          </div>
        </button>
        <button className="flex justify-between items-center pb-5 w-full">
          <h3>Change Password</h3>
          <ChevronRight className="w-5 h-5" />
        </button>
        <button
          onClick={() => {
            logout();
            setSuccess(true);
          }}
          className="flex text-(--color-pending) justify-between items-center w-full"
        >
          <h3 className="text-(--color-pending)">Logout</h3>
          <LogOut className="w-5 h-5" />
        </button>
      </div>
    </div>
  );
}
