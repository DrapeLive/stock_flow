"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { agentApi } from "@/lib/api/agents";
import { itemApi } from "@/lib/api/item";
import { AgentResponse, AgentUpdateRequest, AssignedItem } from "@/types/agent";
import { Item } from "@/types/item";
import {
  Field,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { Trash2, ArrowLeft, ShieldCheck, Search, Check, X, Package } from "lucide-react";

export default function AgentDetailPage() {
  const { id } = useParams();
  const router = useRouter();
  const [agent, setAgent] = useState<AgentResponse | null>(null);
  const [formData, setFormData] = useState({
    username: "",
    email: "",
    contact: "",
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  
  const [items, setItems] = useState<Item[]>([]);
  const [selectedItemIds, setSelectedItemIds] = useState<number[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [savingItems, setSavingItems] = useState(false);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const numericId = parseInt(id as string, 10);
        const [agentData, itemsData] = await Promise.all([
          agentApi.getOne(numericId),
          itemApi.getAll()
        ]);
        setAgent(agentData);
        setItems(itemsData);
        setSelectedItemIds((agentData.assigned_items || []).map((item: AssignedItem) => item.id));
        setFormData({
          username: agentData.user.username,
          email: agentData.user.email,
          contact: agentData.contact,
        });
      } catch (error) {
        console.error("Error fetching agent:", error);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, [id]);

  const handleChange = (key: string, value: string) => {
    setFormData(prev => ({ ...prev, [key]: value }));
    if (errors[key]) setErrors(prev => ({ ...prev, [key]: "" }));
  };

  const handleUpdate = async () => {
    setSaving(true);
    try {
      const numericId = parseInt(id as string, 10);
      const payload: AgentUpdateRequest = {
        username: formData.username,
        email: formData.email,
        contact: formData.contact,
      };
      await agentApi.update(numericId, payload);
      router.refresh();
    } catch (error: any) {
      console.error("Error updating agent:", error);
      setErrors({ submit: "Failed to update agent details." });
    } finally {
      setSaving(false);
    }
  };

  const handleSaveItems = async () => {
    setSavingItems(true);
    try {
      const numericId = parseInt(id as string, 10);
      await agentApi.updateItems(numericId, selectedItemIds);
      const updatedAgent = await agentApi.getOne(numericId);
      setAgent(updatedAgent);
      alert("Items assigned successfully!");
    } catch (error) {
      console.error("Error saving items:", error);
      alert("Failed to save item assignments.");
    } finally {
      setSavingItems(false);
    }
  };

  const toggleItem = (itemId: number) => {
    setSelectedItemIds(prev => 
      prev.includes(itemId) 
        ? prev.filter(id => id !== itemId)
        : [...prev, itemId]
    );
  };

  const filteredItems = items.filter(item => 
    item.name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const assignedItems = items.filter(item => selectedItemIds.includes(item.id));

  const handleDelete = async () => {
    if (confirm("Are you sure you want to delete this agent? This will also delete their user account.")) {
      try {
        const numericId = parseInt(id as string, 10);
        await agentApi.delete(numericId);
        router.push("/admin/users/");
      } catch (error) {
        console.error("Error deleting agent:", error);
      }
    }
  };

  if (loading) return <div className="p-8 text-center text-gray-400">Loading details...</div>;
  if (!agent) return <div className="p-8 text-center text-red-400">Agent not found.</div>;

  return (
    <div className="w-full px-4 py-8 flex flex-col min-h-screen bg-white">
      <div className="flex items-center justify-between mb-8">
        <button onClick={() => router.back()} className="p-2 -ml-2 rounded-full hover:bg-gray-50 transition-colors">
          <ArrowLeft size={24} className="text-gray-900" />
        </button>
        <div className="text-center flex-1">
          <h1 className="text-xl font-black text-gray-900 tracking-tight">Agent Profile</h1>
          <p className="text-[10px] text-gray-400 font-black uppercase tracking-[0.2em]">Personnel Management</p>
        </div>
        <button onClick={handleDelete} className="p-2 rounded-xl text-red-500 hover:bg-red-50 transition-colors">
          <Trash2 size={20} />
        </button>
      </div>

      <div className="flex flex-col items-center mb-8">
        <div className="w-20 h-20 bg-blue-50 rounded-3xl flex items-center justify-center mb-4 shadow-sm">
          <ShieldCheck size={40} className="text-blue-500" />
        </div>
        <h2 className="text-2xl font-black text-gray-900">{agent.user.username}</h2>
        <span className="text-xs font-bold text-gray-400 mt-1">FIELD AGENT</span>
      </div>

      <div className="bg-gray-50/50 border border-gray-100 rounded-[2rem] p-6 space-y-6 mb-8">
        <FieldGroup className="space-y-6">
          <Field>
            <FieldLabel className="text-[10px] font-black uppercase tracking-widest text-gray-400 mb-2 block">Full username</FieldLabel>
            <Input
              value={formData.username}
              onChange={(e) => handleChange("username", e.target.value)}
              className="bg-white border-gray-100 rounded-xl h-12 font-bold"
            />
          </Field>

          <Field>
            <FieldLabel className="text-[10px] font-black uppercase tracking-widest text-gray-400 mb-2 block">Email Address</FieldLabel>
            <Input
              value={formData.email}
              onChange={(e) => handleChange("email", e.target.value)}
              className="bg-white border-gray-100 rounded-xl h-12 font-bold"
            />
          </Field>

          <Field>
            <FieldLabel className="text-[10px] font-black uppercase tracking-widest text-gray-400 mb-2 block">Contact number</FieldLabel>
            <Input
              value={formData.contact}
              onChange={(e) => handleChange("contact", e.target.value)}
              className="bg-white border-gray-100 rounded-xl h-12 font-bold"
            />
          </Field>
        </FieldGroup>
      </div>

      <div className="mb-4">
        <StockFlowButton
          variant="filled"
          text={saving ? "Updating..." : "Update Details"}
          onClick={handleUpdate}
          disabled={saving}
          className="w-full h-14 rounded-2xl bg-primary text-white font-bold shadow-lg shadow-primary/20 flex items-center justify-center gap-2 active:scale-95 transition-all"
        />
      </div>

      <div className="border-t border-gray-100 pt-8 mt-4">
        <h3 className="text-lg font-black text-gray-900 mb-2">Assigned Items</h3>
        <p className="text-xs text-gray-400 font-medium mb-6">Select items this agent can order</p>

        {assignedItems.length > 0 && (
          <div className="mb-6">
            <p className="text-[10px] font-black uppercase tracking-widest text-gray-400 mb-3">Currently Assigned ({assignedItems.length})</p>
            <div className="flex flex-wrap gap-2">
              {assignedItems.map(item => (
                <div
                  key={item.id}
                  className="flex items-center gap-2 px-3 py-2 bg-primary/10 rounded-xl border border-primary/20"
                >
                  {item.variants?.[0]?.image ? (
                    <img src={item.variants[0].image} alt={item.name} className="w-5 h-5 rounded object-cover" />
                  ) : (
                    <Package size={14} className="text-primary" />
                  )}
                  <span className="text-xs font-bold text-primary">{item.name}</span>
                  <button
                    onClick={() => toggleItem(item.id)}
                    className="p-0.5 hover:bg-primary/20 rounded"
                  >
                    <X size={12} className="text-primary" />
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="relative mb-4">
          <Search size={18} className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" />
          <Input
            placeholder="Search items to assign..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-11 bg-white border-gray-100 rounded-xl h-12 font-bold"
          />
        </div>

        <div className="space-y-2 max-h-64 overflow-y-auto mb-6">
          {filteredItems.map(item => {
            const isSelected = selectedItemIds.includes(item.id);
            return (
              <button
                key={item.id}
                onClick={() => toggleItem(item.id)}
                className={`w-full flex items-center justify-between p-4 rounded-xl border-2 transition-all ${
                  isSelected
                    ? "border-primary bg-primary/5"
                    : "border-gray-100 hover:border-gray-200"
                }`}
              >
                <div className="flex items-center gap-3">
                  <div className={`w-5 h-5 rounded-md border-2 flex items-center justify-center ${
                    isSelected ? "border-primary bg-primary" : "border-gray-300"
                  }`}>
                    {isSelected && <Check size={12} className="text-white" />}
                  </div>
                  <div className="text-left">
                    <p className="font-bold text-gray-900">{item.name}</p>
                    <p className="text-[10px] text-gray-400 uppercase">{item.type} • ₹{item.price}</p>
                  </div>
                </div>
              </button>
            );
          })}
          {filteredItems.length === 0 && (
            <p className="text-center text-gray-400 py-4 text-sm">No items found</p>
          )}
        </div>

        <StockFlowButton
          variant="filled"
          text={savingItems ? "Saving..." : `Save Item Assignments (${selectedItemIds.length})`}
          onClick={handleSaveItems}
          disabled={savingItems}
          className="w-full h-12 rounded-2xl bg-green-600 text-white font-bold shadow-lg shadow-green-600/20 flex items-center justify-center gap-2 active:scale-95 transition-all"
        />
      </div>

      <div className="h-20"></div>
    </div>
  );
}
