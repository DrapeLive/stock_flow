"use client";

import type { TrendPoint } from "@/types/dashboard";

interface TrendSparklineProps {
  data: TrendPoint[];
  from: string;
  to: string;
}

export default function TrendSparkline({ data, from, to }: TrendSparklineProps) {
  if (data.length === 0) {
    return (
      <div className="bg-white rounded-xl border p-4 shadow-sm mb-4">
        <div className="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-2">
          Orders Trend
        </div>
        <div className="h-24 flex items-center justify-center text-gray-400 text-xs">
          No data in range
        </div>
      </div>
    );
  }

  const mapDates = () => {
    const dateMap = new Map<string, number>();
    data.forEach((d) => dateMap.set(d.day, d.count));

    const start = new Date(from + "T00:00:00");
    const end = new Date(to + "T00:00:00");
    const filled: { day: string; count: number }[] = [];

    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
      const key = d.toISOString().split("T")[0];
      filled.push({ day: key, count: dateMap.get(key) || 0 });
    }

    return filled;
  };

  const filled = mapDates();
  const maxCount = Math.max(...filled.map((d) => d.count), 1);

  const width = 300;
  const height = 80;
  const padding = { top: 10, right: 10, bottom: 20, left: 30 };
  const chartW = width - padding.left - padding.right;
  const chartH = height - padding.top - padding.bottom;

  const points = filled.map((d, i) => {
    const x = padding.left + (i / (filled.length - 1 || 1)) * chartW;
    const y = padding.top + chartH - (d.count / maxCount) * chartH;
    return `${x},${y}`;
  });

  const tickDates = filled.filter(
    (_, i) => i === 0 || i === filled.length - 1 || i === Math.floor(filled.length / 2)
  );

  return (
    <div className="bg-white rounded-xl border p-4 shadow-sm mb-4">
      <div className="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-2">
        Orders Trend
      </div>
      <svg viewBox={`0 0 ${width} ${height}`} className="w-full" preserveAspectRatio="none">
        <polyline
          points={points.join(" ")}
          fill="none"
          stroke="#3b82f6"
          strokeWidth="2"
          strokeLinejoin="round"
        />
        {tickDates.map((d, i) => {
          const x =
            padding.left +
            (filled.indexOf(d) / (filled.length - 1 || 1)) * chartW;
          return (
            <text
              key={i}
              x={x}
              y={height - 5}
              textAnchor="middle"
              fontSize="8"
              fill="#9ca3af"
            >
              {new Date(d.day + "T00:00:00").toLocaleDateString("en-US", {
                month: "short",
                day: "numeric",
              })}
            </text>
          );
        })}
      </svg>
    </div>
  );
}
