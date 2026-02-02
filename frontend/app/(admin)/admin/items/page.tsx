import { Plus } from "lucide-react";

export default function ItemsPage() {
  return (
    <div className="min-h-screen min-w-full">
      <div className="pt-2 flex justify-between">
        <div className="flex gap-1 items-center">
          <p>Total Item</p>
          <div className="bg-(--color-border) rounded-full py-0.5 px-2">
            <p className="font-bold">40</p>
          </div>
        </div>
        <button className="p-1 rounded-md bg-(--color-primary) text-white border border-(--color-border)">
          <div className="flex items-center gap-1">
            <p>Add new Item</p>
            <Plus size={16} />
          </div>
        </button>
      </div>
    </div>
  );
}
