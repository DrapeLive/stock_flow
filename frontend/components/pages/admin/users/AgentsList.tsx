import { Plus } from "lucide-react";

const AgentsList: React.FC = () => {
  return (
    <>
      <div className="pt-2 flex justify-between">
        <div className="flex gap-1 items-center">
          <p>Remaining Order</p>
          <div className="bg-(--color-border) rounded-full py-0.5 px-2">
            <p className="font-bold">40</p>
          </div>
        </div>
        <button className="p-1 rounded-md bg-(--color-primary) text-white border border-(--color-border)">
          <div className="flex items-center gap-1">
            <p>Add new Agents</p>
            <Plus size={16} />
          </div>
        </button>
      </div>
    </>
  );
};

export default AgentsList;
