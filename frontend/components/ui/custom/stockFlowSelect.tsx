"use client";

import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

interface StockFlowSelectProps {
  value: string;
  onChange: (value: string) => void;
}

export default function StockFlowSelect({
  value,
  onChange,
}: StockFlowSelectProps) {
  return (
    <Select value={value} onValueChange={onChange}>
      <SelectTrigger className="w-full">
        <SelectValue placeholder="Select Agent" />
      </SelectTrigger>
      <SelectContent>
        <SelectGroup>
          <SelectItem value="john_doe">John Doe</SelectItem>
          <SelectItem value="agent_2">Agent 2</SelectItem>
          <SelectItem value="agent_3">Agent 3</SelectItem>
        </SelectGroup>
      </SelectContent>
    </Select>
  );
}
