import AdminNavBar from "@/components/ui/AdminNavBar";
import AdminProfileButton from "@/components/ui/custom/adminProfileButton";

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="admin-order-layout pb-32">
      <AdminProfileButton />
      {children}
      <AdminNavBar />
    </div>
  );
}
