import Link from "next/link";
import { X } from "lucide-react";

export default function OrderLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="admin-order-layout">
      <h1 className="text-(--color-primary) flex justify-center">
        Create new Order
      </h1>
      {children}
      <div className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full">
        <div className="w-full flex justify-center pb-5">
          <Link
            href="/"
            className="flex gap-1 text-(--color-primary) border border-(--color-primary) p-1.5 rounded-md"
          >
            Cancel{" "}
            <span>
              <X />
            </span>
          </Link>
        </div>
      </div>
    </div>
  );
}
