import { useState } from "react";
import { X } from "lucide-react";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import AddSizeDialog from "./addSizeDialog";

interface Size {
  id: string;
  label: string;
  quantity: string;
}

export default function SizesSection({
  sizes,
  setSizes,
}: {
  sizes: Size[];
  setSizes: React.Dispatch<React.SetStateAction<Size[]>>;
}) {
  const [open, setOpen] = useState(false);

  const addSize = (size: { label: string; quantity: string }) => {
    setSizes((prev) => [...prev, { id: crypto.randomUUID(), ...size }]);
  };

  const removeSize = (id: string) => {
    setSizes((prev) => prev.filter((s) => s.id !== id));
  };

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h3 className="font-medium">Sizes</h3>
        <StockFlowButton
          variant="filled"
          text="Add +"
          onClick={() => setOpen(true)}
        />
      </div>

      {sizes.length === 0 ? (
        <p className="text-sm text-gray-400">No sizes added yet</p>
      ) : (
        sizes.map((size) => (
          <div
            key={size.id}
            className="flex justify-between items-center border-b py-2"
          >
            <span>{size.label}</span>
            <span className="text-sm text-gray-500">{size.quantity} pcs</span>
            <button onClick={() => removeSize(size.id)}>
              <X size={16} className="text-red-500" />
            </button>
          </div>
        ))
      )}

      <AddSizeDialog
        open={open}
        onClose={() => setOpen(false)}
        onAdd={addSize}
      />
    </div>
  );
}
