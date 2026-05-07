"use client";

import AdminNavBar from "@/components/ui/AdminNavBar";
import AdminProfileButton from "@/components/ui/custom/adminProfileButton";
import PushNotificationInit from "@/lib/pushInit";
import { usePathname } from "next/navigation";

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const isStatusPage = pathname.includes("/admin/order/status/");

  return (
    <div className={`admin-order-layout ${isStatusPage ? "" : "pb-32"}`}>
      <PushNotificationInit />
      <AdminProfileButton />
      {children}
      {!isStatusPage && <AdminNavBar />}
    </div>
  );
}
