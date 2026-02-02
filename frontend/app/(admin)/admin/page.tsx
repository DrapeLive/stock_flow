import { Filter } from "lucide-react";

export default function AdminHomePage() {
  return (
    <div className="min-h-screen min-w-full">
      <div className="border p-1 mt-2 flex items-center justify-between space-x-1 border-(--color-border) rounded-full">
        <button className="bg-(--color-primary) rounded-full px-4 py-0.5 text-white font-semibold text-xs">
          All
        </button>
        <button className="bg-(--color-primary) rounded-full px-4 py-0.5 text-white font-semibold text-xs">
          Pending
        </button>
        <button className="bg-(--color-primary) rounded-full px-4 py-0.5 text-white font-semibold text-xs">
          Packed
        </button>
        <button className="bg-(--color-primary) rounded-full px-4 py-0.5 text-white font-semibold text-xs">
          Dispatched
        </button>
      </div>
      <div className="pt-2 flex justify-between">
        <div className="flex gap-1 items-center">
          <p>Remaining Order</p>
          <div className="bg-(--color-border) rounded-full py-0.5 px-2">
            <p className="font-bold">40</p>
          </div>
        </div>
        <div className="p-0.5 rounded-[3px] border border-(--color-border)">
          <Filter className="text-(--color-border) w-2.5 h-2.5" />
        </div>
      </div>
    </div>
  );
}
