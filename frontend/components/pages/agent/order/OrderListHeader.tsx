"use client";
import FilterToggle from "@/components/ui/FilterToggle";

interface OrderListHeaderProps {
  title: string;
  count: number;
  countColor?: "amber" | "green";
  showFilters: boolean;
  handleToggleFilters: () => void;
}

export default function OrderListHeader({
  title,
  count,
  countColor = "amber",
  showFilters,
  handleToggleFilters,
}: OrderListHeaderProps) {
  const badgeColorClasses = {
    amber: "bg-amber-100 text-amber-600 border-amber-200",
    green: "bg-green-100 text-green-600 border-green-200",
  };

  return (
    <div className="pt-4 flex justify-between items-center mb-6">
      <div className="flex gap-2 items-center">
        <span className="text-gray-400 text-[10px] font-bold uppercase tracking-wider">
          {title}
        </span>
        <div
          className={`rounded-full py-0.5 px-3 border ${badgeColorClasses[countColor]}`}
        >
          <span className="font-bold text-xs">{count}</span>
        </div>
      </div>
      <div>
        <FilterToggle isOpen={showFilters} onToggle={handleToggleFilters} />
      </div>
    </div>
  );
}
