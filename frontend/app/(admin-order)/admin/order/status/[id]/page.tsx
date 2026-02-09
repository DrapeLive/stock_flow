import { ChevronLeft, Plus } from "lucide-react";
import Link from "next/link";

export default async function Page({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  return (
    <div className="min-h-screen min-w-full">
      <div className="w-full">
        <Link
          className="flex text-(--color-primary) items-center"
          href={"/admin/"}
        >
          <ChevronLeft size={18} />
          <h5>Back</h5>
        </Link>
      </div>
      <div className="border p-1 mt-2 flex items-center justify-center space-x-1 border-(--color-border) rounded-full">
        <button className="bg-(--color-primary) rounded-full px-12 py-1 text-white font-semibold text-xs">
          Packing
        </button>
        <button className="bg-(--color-primary) rounded-full px-12 py-1 text-white font-semibold text-xs">
          Dispatching
        </button>
      </div>
      <h2 className="mt-2 font-medium">Order Details</h2>
      <div className="space-y-2">
        <h3>
          <span className="text-(--color-text)">Customer: </span>Mens Fashion
          Club
        </h3>
        <h3>
          <span className="text-(--color-text)">Agent: </span>John Doe
        </h3>
        <h3>
          <span className="text-(--color-text)">Order Date: </span>22 De, 2025
        </h3>
        <div className="flex">
          <h3 className="text-(--color-text)">Current status: </h3>
          <div className="ml-2 rounded-full bg-(--color-pending)/20 border border-(--color-pending) px-3 py-0.5">
            <p className="text-(--color-pending)">Pending</p>
          </div>
        </div>
      </div>
      <div className="pt-4 flex justify-between">
        <div className="text-[20px]">Package Status</div>
        <button className="p-2 bg-(--color-primary) flex gap-1 items-center text-white rounded-md">
          <h5>Edit</h5>
          <Plus size={18} />
        </button>
      </div>
    </div>
  );
}
