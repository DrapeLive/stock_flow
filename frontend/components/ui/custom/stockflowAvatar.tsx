import { Admin } from "@/types/admin";
import { AgentUser } from "@/types/agent";
import { AuthUser } from "@/types/auth";
import { SimpleAgent, SimpleCustomer } from "@/types/order";
import { getColorFromId } from "@/util/getColorFromId";
import { User } from "lucide-react";

interface stockflowAvatarProps {
  user?: AuthUser | SimpleAgent | SimpleCustomer | AgentUser | Admin | null;
}

const StockflowAvatar: React.FC<stockflowAvatarProps> = ({ user }) => {
  const username =
    user && "display_name" in user && (user as any).display_name
      ? (user as any).display_name
      : user && "username" in user && user.username
        ? user.username
        : user && "name" in user && user.name
          ? user.name
          : "";
  return (
    <div
      className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 border border-gray-100 shadow-sm"
      style={{
        backgroundColor: getColorFromId(user?.id || 1),
      }}
    >
      {username.trim().length > 0 ? (
        <span className="text-white font-bold">{username[0]}</span>
      ) : (
        <User size={18} color="white" />
      )}
    </div>
  );
};

export default StockflowAvatar;
