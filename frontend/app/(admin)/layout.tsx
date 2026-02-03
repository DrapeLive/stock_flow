import AdminNavBar from "@/components/ui/AdminNavBar";
import AdminInputBar from "@/components/ui/custom/adminInputBar";

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="admin-order-layout">
      <AdminInputBar />
      {children}
      <AdminNavBar />
    </div>
  );
}
