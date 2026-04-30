"use client";

import { useState } from "react";
import DatePicker from "@/components/ui/date-picker";

interface RangePresetsProps {
  onRangeChange: (from: string, to: string) => void;
}

type Preset = "today" | "7d" | "30d" | "custom";

export default function RangePresets({ onRangeChange }: RangePresetsProps) {
  const [activePreset, setActivePreset] = useState<Preset>("30d");
  const [customFrom, setCustomFrom] = useState("");
  const [customTo, setCustomTo] = useState("");

  const applyPreset = (preset: Preset) => {
    setActivePreset(preset);
    const now = new Date();
    const to = now.toISOString().split("T")[0];
    let from = to;

    if (preset === "today") {
      from = to;
    } else if (preset === "7d") {
      const d = new Date(now);
      d.setDate(d.getDate() - 7);
      from = d.toISOString().split("T")[0];
    } else if (preset === "30d") {
      const d = new Date(now);
      d.setDate(d.getDate() - 30);
      from = d.toISOString().split("T")[0];
    } else {
      return;
    }

    onRangeChange(from, to);
  };

  const handleCustomApply = () => {
    if (customFrom && customTo) {
      onRangeChange(customFrom, customTo);
    }
  };

  return (
    <div className="sticky top-0 z-10 bg-white/90 backdrop-blur py-2 -mx-1.5 px-1.5">
      <div className="flex gap-2 mb-2">
        {[
          { key: "today" as Preset, label: "Today" },
          { key: "7d" as Preset, label: "7d" },
          { key: "30d" as Preset, label: "30d" },
          { key: "custom" as Preset, label: "Custom" },
        ].map(({ key, label }) => (
          <button
            key={key}
            onClick={() => {
              if (key === "custom") {
                setActivePreset(key);
              } else {
                applyPreset(key);
              }
            }}
            className={`flex-1 py-1.5 text-xs font-bold rounded-full transition-all ${
              activePreset === key
                ? "bg-primary text-white shadow"
                : "bg-gray-100 text-gray-600 hover:bg-gray-200"
            }`}
          >
            {label}
          </button>
        ))}
      </div>
      {activePreset === "custom" && (
        <div className="flex gap-2 items-center">
          <DatePicker
            value={customFrom}
            onChange={setCustomFrom}
            placeholder="From"
          />
          <span className="text-gray-400 text-xs">to</span>
          <DatePicker
            value={customTo}
            onChange={setCustomTo}
            placeholder="To"
          />
          <button
            onClick={handleCustomApply}
            className="text-xs font-bold text-primary"
          >
            Apply
          </button>
        </div>
      )}
    </div>
  );
}
