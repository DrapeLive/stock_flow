import { SizeRangeProvider } from "@/context/SizeRangeContext";

export default function OrderLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="admin-order-layout">
      <SizeRangeProvider>{children}</SizeRangeProvider>
    </div>
  );
}
