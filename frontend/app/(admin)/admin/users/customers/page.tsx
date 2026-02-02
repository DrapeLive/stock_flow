import { Plus } from "lucide-react";

export default function CustomersPage() {
  return (
    <div className="min-h-screen min-w-full">
      <div className="border p-1 mt-2 flex items-center justify-center space-x-1 border-(--color-border) rounded-full">
        <button className="bg-(--color-primary) rounded-full px-13.5 py-1 text-white font-semibold text-xs">
          Customers
        </button>
        <button className="bg-(--color-primary) rounded-full px-13.5 py-1 text-white font-semibold text-xs">
          Agents
        </button>
      </div>
      <div className="pt-2 flex justify-between">
        <div className="flex gap-1 items-center">
          <p>Remaining Order</p>
          <div className="bg-(--color-border) rounded-full py-0.5 px-2">
            <p className="font-bold">40</p>
          </div>
        </div>
        <button className="p-1 rounded-md bg-(--color-primary) text-white border border-(--color-border)">
          <div className="flex items-center gap-1">
            <p>Add new Customers</p>
            <Plus size={16} />
          </div>
        </button>
      </div>
    </div>
  );
}
