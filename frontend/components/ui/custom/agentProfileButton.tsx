"use client";

import { useRouter } from "next/navigation";
import StockflowAvatar from "./stockflowAvatar";
import { useAuth } from "@/context/AuthContext";

const AgentProfileButton: React.FC = () => {
  const router = useRouter();
  const { user } = useAuth();

  return (
    <div
      className="flex relative w-full justify-end cursor-pointer pt-2 pr-2"
      onClick={() => router.push("/agent/profile")}
      title="View Profile"
    >
      <StockflowAvatar user={user} />
    </div>
  );
};

export default AgentProfileButton;
