"use client";

import { useAuth } from "@/context/AuthContext";
import { useRouter } from "next/navigation";
import StockflowAvatar from "./stockflowAvatar";

const AdminProfileButton: React.FC = () => {
  const router = useRouter();
  const { business, isSuperuser, user } = useAuth();

  const businessLabel = business
    ? business.charAt(0).toUpperCase() + business.slice(1)
    : "";

  return (
    <div
      className="flex relative w-full justify-between cursor-pointer"
      onClick={() => router.push("/admin/profile")}
    >
      <div className="flex items-center px-2 py-1 text-primary text-md font-black tracking-wider">
        {businessLabel ? businessLabel : isSuperuser ? "Superuser" : ""}
      </div>
      <StockflowAvatar user={user} />
    </div>
  );
};

export default AdminProfileButton;
