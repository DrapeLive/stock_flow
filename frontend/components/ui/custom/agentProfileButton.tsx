"use client";

import { Avatar, AvatarFallback } from "../avatar";
import { useRouter } from "next/navigation";

const AgentProfileButton: React.FC = () => {
  const router = useRouter();

  return (
    <div
      className="flex relative w-full justify-end cursor-pointer pt-2 pr-2"
      onClick={() => router.push("/agent/profile")}
      title="View Profile"
    >
      <Avatar>
        <AvatarFallback>A</AvatarFallback>
      </Avatar>
    </div>
  );
};

export default AgentProfileButton;
