import QRPrintPageContent from "@/components/pages/items/qr/QRPageContent";
import { Suspense } from "react";

export default function QRPrintPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center">
          Loading...
        </div>
      }
    >
      <QRPrintPageContent />
    </Suspense>
  );
}
