import ListCustomer from "@/components/pages/ListCustomer";
import { X } from "lucide-react";
import Link from "next/link";

export default function NewOrder() {
  return (
    <>
      <h1 className="text-(--color-primary) flex justify-center">
        Create new Order
      </h1>
      <ListCustomer />
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
    </>
  );
}
