"use client";

import { Input } from "./input";
import StockFlowSelect from "./custom/stockFlowSelect";

interface FilterBarProps {
  fromDate: string;
  toDate: string;
  onFromDateChange: (date: string) => void;
  onToDateChange: (date: string) => void;
  agents?: { id: number; username: string }[];
  selectedAgent?: string;
  onAgentChange?: (agentId: string) => void;
}

export default function FilterBar({
  fromDate,
  toDate,
  onFromDateChange,
  onToDateChange,
  agents = [],
  selectedAgent = "",
  onAgentChange,
}: FilterBarProps) {
  return (
    <div className="flex flex-wrap gap-2 items-center mb-4 p-2 bg-gray-50 rounded-lg">
      <div className="relative flex-1 min-w-[140px]">
        <Input
          type="date"
          value={fromDate}
          onChange={(e) => onFromDateChange(e.target.value)}
          placeholder="From date"
        />
      </div>
      <span className="text-gray-400 text-xs">to</span>
      <div className="relative flex-1 min-w-[140px]">
        <Input
          type="date"
          value={toDate}
          onChange={(e) => onToDateChange(e.target.value)}
          placeholder="To date"
        />
      </div>
      {agents.length > 0 && onAgentChange && (
        <>
          <span className="text-gray-400 text-xs">Agent</span>
          <div className="flex-1 min-w-[140px]">
            <StockFlowSelect
              value={selectedAgent}
              onChange={onAgentChange}
              placeholder="All Agents"
              options={[
                { value: "all", label: "All Agents" },
                ...agents.map((a) => ({
                  value: String(a.id),
                  label: a.username,
                })),
              ]}
            />
          </div>
        </>
      )}
    </div>
  );
}
