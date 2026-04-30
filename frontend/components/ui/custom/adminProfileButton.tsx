"use client";

import { useAuth } from "@/context/AuthContext";
import { Avatar, AvatarFallback } from "../avatar";
import { useRouter } from "next/navigation";

const AdminProfileButton: React.FC = () => {
  const router = useRouter();
  const { business, isSuperuser } = useAuth();

  const businessLabel = business
    ? business.charAt(0).toUpperCase() + business.slice(1)
    : "";

  return (
    <div
      className="flex relative w-full justify-between cursor-pointer"
      onClick={() => router.push("/admin/profile")}
    >
      {businessLabel && (
        <div className="flex items-center px-2 py-1 text-primary text-md font-black uppercase tracking-wider">
          {businessLabel}
        </div>
      )}
      {isSuperuser && (
        <div className="flex items-center px-2 py-1 text-primary text-md font-black uppercase tracking-wider">
          Superuser
        </div>
      )}
      <Avatar>
        <AvatarFallback>A</AvatarFallback>
      </Avatar>
    </div>
  );
};

export default AdminProfileButton;
