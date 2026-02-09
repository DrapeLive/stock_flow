import { ChevronLeft, Save } from "lucide-react";
import Link from "next/link";

export default function EditOrderPage() {
  return (
    <div className="min-h-screen min-w-full">
      <div className="w-full">
        <Link
          className="flex text-(--color-primary) items-center"
          href={"/admin/order/status/1"}
        >
          <ChevronLeft size={18} />
          <h5>Back</h5>
        </Link>
      </div>
      <div className="mt-3 flex justify-between">
        <div className="text-[20px]">Ordered Items</div>
        <button className="flex gap-1 text-white bg-(--color-primary) items-center rounded-md px-2 py-1">
          <h5>Save</h5>
          <Save />
        </button>
      </div>
    </div>
  );
}
