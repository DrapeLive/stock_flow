"use client";

import { Avatar, AvatarFallback } from "../avatar";
import { useRouter } from "next/navigation";

const AdminProfileButton: React.FC = () => {
  const router = useRouter();

  return (
    <div
      className="flex relative w-full justify-end cursor-pointer"
      onClick={() => router.push("/admin/profile")}
    >
      <Avatar>
        <AvatarFallback>A</AvatarFallback>
      </Avatar>
    </div>
  );
};

export default AdminProfileButton;
