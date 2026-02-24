import { useState, useEffect } from "react";
import { X } from "lucide-react";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import AddColorDialog from "./addColorDialog";

interface Color {
  id: string;
  name: string;
  image: File | null;
}

export default function ColorsSection({
  colors,
  setColors,
}: {
  colors: Color[];
  setColors: React.Dispatch<React.SetStateAction<Color[]>>;
}) {
  const [open, setOpen] = useState(false);

  const addColor = (color: { name: string; image: File | null }) => {
    setColors((prev) => [...prev, { id: crypto.randomUUID(), ...color }]);
  };

  const removeColor = (id: string) => {
    setColors((prev) => prev.filter((c) => c.id !== id));
  };

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h3 className="font-medium">Colors</h3>
        <StockFlowButton
          variant="filled"
          text="Add +"
          onClick={() => setOpen(true)}
        />
      </div>

      {colors.length === 0 ? (
        <p className="text-sm text-gray-400">No colors added yet</p>
      ) : (
        colors.map((color) => (
          <div key={color.id} className="flex items-center gap-4 border-b py-2">
            {color.image && (
              <ColorPreview file={color.image} />
            )}
            <span>{color.name}</span>
            <button onClick={() => removeColor(color.id)} className="ml-auto">
              <X size={16} className="text-red-500" />
            </button>
          </div>
        ))
      )}

      <AddColorDialog
        open={open}
        onClose={() => setOpen(false)}
        onAdd={addColor}
      />
    </div>
  );
}

function ColorPreview({ file }: { file: File }) {
  const [url, setUrl] = useState<string | null>(null);

  useEffect(() => {
    const objectUrl = URL.createObjectURL(file);
    setUrl(objectUrl);
    return () => URL.revokeObjectURL(objectUrl);
  }, [file]);

  if (!url) return null;

  return (
    <img
      src={url}
      className="w-12 h-12 aspect-square object-cover rounded"
    />
  );
}
