"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { agentApi } from "@/lib/api/agents";
import { itemApi } from "@/lib/api/item";
import { toastSuccess, toastError } from "@/lib/toast";
import { AgentResponse, AgentUpdateRequest, AssignedItem } from "@/types/agent";
import { Item, ItemAllResponse } from "@/types/item";
import { Field, FieldGroup, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { deriveUsername } from "@/lib/utils/deriveUsername";
import { Trash2, ArrowLeft, ShieldCheck, Pencil, Eye } from "lucide-react";
import ItemAssignment from "@/components/pages/agent/ItemAssignment";
import DeleteWithTransferDialog from "@/components/ui/deleteWithTransferDialog";
import { useAuth } from "@/context/AuthContext";
import { PageLoading } from "@/components/ui/Loading";

function getColorFromId(id: number): string {
  if (!id) return "hsl(0, 0%, 85%)";
  const hue = (id * 137.508) % 360;
  return `hsl(${hue}, 65%, 85%)`;
}

export default function AgentDetailPage() {
  const { id } = useParams();
  const router = useRouter();
  const { isSuperuser } = useAuth();

  const [agent, setAgent] = useState<AgentResponse | null>(null);
  const [formData, setFormData] = useState({
    username: "",
    display_name: "",
    email: "",
    contact: "",
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isEditing, setIsEditing] = useState(false);

  const [items, setItems] = useState<Item[]>([]);

  // Single source of truth: mirrors exactly what is checked in the UI.
  // Seeded from the backend on load and re-synced after every save.
  const [selectedVariantIds, setSelectedVariantIds] = useState<number[]>([]);

  // Snapshot of what the backend last confirmed.
  // Used only to compute hasChanges — never rendered directly.
  const [savedVariantIds, setSavedVariantIds] = useState<number[]>([]);

  const [savingItems, setSavingItems] = useState(false);

  const [variantCreatedAt, setVariantCreatedAt] = useState<Map<number, string>>(
    new Map(),
  );

  useEffect(() => {
    const fetchData = async () => {
      try {
        const numericId = parseInt(id as string, 10);
        const [agentData, itemsData] = await Promise.all([
          agentApi.getOne(numericId),
          itemApi.getAll(),
        ]);
        setAgent(agentData);
        setItems(itemsData);
        const ids = (agentData.assigned_items || []).flatMap(
          (item: AssignedItem) => item.variants.map((v) => v.id),
        );
        // Build variantId → created_at map from backend
        const createdAtMap = new Map<number, string>();
        for (const item of agentData.assigned_items || []) {
          for (const v of item.variants) {
            if (v.created_at) {
              createdAtMap.set(v.id, v.created_at);
            }
          }
        }
        setVariantCreatedAt(createdAtMap);
        // Both states start equal — no unsaved changes on first load
        setSelectedVariantIds(ids);
        setSavedVariantIds(ids);
        setFormData({
          username: agentData.user.username,
          display_name: agentData.user.display_name || "",
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
    setFormData((prev) => ({ ...prev, [key]: value }));
    if (errors[key]) setErrors((prev) => ({ ...prev, [key]: "" }));
  };

  const handleUpdate = async () => {
    setSaving(true);
    try {
      const numericId = parseInt(id as string, 10);
      const username = deriveUsername(
        formData.display_name || formData.username,
      );
      const payload: AgentUpdateRequest = {
        username,
        display_name: formData.display_name,
        email: formData.email,
        contact: formData.contact,
      };
      await agentApi.update(numericId, payload);
      toastSuccess("Agent details updated");
      setIsEditing(false);
      router.push("/admin/users/");
    } catch (error: any) {
      console.error("Error updating agent:", error);
      toastError("Failed to update agent details", error);
    } finally {
      setSaving(false);
    }
  };

  const handleSaveItems = async () => {
    setSavingItems(true);
    try {
      const numericId = parseInt(id as string, 10);
      // Send the full current selection — backend does delete-then-insert,
      // so this correctly handles both additions and removals.
      await agentApi.updateItems(numericId, selectedVariantIds);
      const updatedAgent = await agentApi.getOne(numericId);
      setAgent(updatedAgent);
      const confirmedIds = (updatedAgent.assigned_items || []).flatMap(
        (item: AssignedItem) => item.variants.map((v) => v.id),
      );
      // Rebuild createdAt map from refreshed agent data
      const createdAtMap = new Map<number, string>();
      for (const item of updatedAgent.assigned_items || []) {
        for (const v of item.variants) {
          if (v.created_at) {
            createdAtMap.set(v.id, v.created_at);
          }
        }
      }
      setVariantCreatedAt(createdAtMap);
      // Sync both states to what the backend confirmed
      setSelectedVariantIds(confirmedIds);
      setSavedVariantIds(confirmedIds);
      toastSuccess("Items updated successfully");
    } catch (error) {
      console.error("Error saving items:", error);
      toastError("Failed to save item assignments", error);
    } finally {
      setSavingItems(false);
    }
  };

  // Toggling any variant simply adds or removes it from selectedVariantIds
  const toggleVariant = (variantId: number) => {
    setSelectedVariantIds((prev) =>
      prev.includes(variantId)
        ? prev.filter((i) => i !== variantId)
        : [...prev, variantId],
    );
  };

  // True when the checked variants differ from the last confirmed backend state
  const hasChanges =
    [...selectedVariantIds].sort().join(",") !==
    [...savedVariantIds].sort().join(",");

  // ── Delete ────────────────────────────────────────────────────────────────

  const handleDeleteClick = () => {
    setDeleteDialogOpen(true);
  };

  const handleDeleteConfirm = async (
    _id: number,
    payload: {
      pin: string;
      action: "transfer" | "deactivate";
      transfer_to_id?: number;
    },
  ) => {
    setDeleting(true);
    try {
      await agentApi.delete(
        _id,
        payload.pin,
        payload.action,
        payload.transfer_to_id,
      );
      toastSuccess("Agent deleted successfully");
      router.push("/admin/users/");
    } catch (error) {
      setDeleting(false);
      throw error;
    }
  };

  // ── Render ────────────────────────────────────────────────────────────────

  if (loading) return <PageLoading />;
  if (!agent)
    return <div className="p-8 text-center text-red-400">Agent not found.</div>;

  return (
    <div className="w-full px-4 py-8 flex flex-col min-h-screen bg-white">
      <DeleteWithTransferDialog
        open={deleteDialogOpen}
        onClose={() => setDeleteDialogOpen(false)}
        entityType="agent"
        entityId={parseInt(id as string, 10)}
        entityName={agent?.user.display_name || agent?.user.username || ""}
        onFetchDeleteInfo={agentApi.getDeleteInfo}
        onDelete={handleDeleteConfirm}
        isSuperuser={isSuperuser}
      />

      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <button
          onClick={() => router.push("/admin/users/")}
          className="p-2 -ml-2 rounded-full hover:bg-gray-50 transition-colors"
        >
          <ArrowLeft size={24} className="text-gray-900" />
        </button>
        <div className="text-center flex-1">
          <h1 className="text-xl font-black text-gray-900 tracking-tight">
            Agent Profile
          </h1>
          <p className="text-[10px] text-gray-400 font-black uppercase tracking-[0.2em]">
            Personnel Management
          </p>
        </div>
        <div className="flex items-center gap-1">
          <button
            onClick={() => setIsEditing(!isEditing)}
            className="p-2 rounded-xl hover:bg-gray-50 transition-colors"
            title={isEditing ? "View details" : "Edit details"}
          >
            {isEditing ? (
              <Eye size={20} className="text-gray-700" />
            ) : (
              <Pencil size={20} className="text-gray-700" />
            )}
          </button>
          <button
            onClick={handleDeleteClick}
            disabled={deleting}
            className="p-2 rounded-xl text-red-500 hover:bg-red-50 transition-colors disabled:opacity-40"
          >
            {deleting ? (
              <span className="w-5 h-5 border-2 border-red-300 border-t-red-500 rounded-full animate-spin block" />
            ) : (
              <Trash2 size={20} />
            )}
          </button>
        </div>
      </div>

      {/* Avatar Section */}
      <div className="flex flex-col items-center mb-6">
        <div
          className="w-20 h-20 rounded-3xl flex items-center justify-center mb-4 shadow-sm"
          style={{
            backgroundColor: isEditing ? "#eff6ff" : getColorFromId(agent.id),
          }}
        >
          <ShieldCheck
            size={40}
            className={isEditing ? "text-blue-500" : "text-gray-600"}
          />
        </div>
        <h2 className="text-2xl font-black text-gray-900">
          {agent.user.display_name || agent.user.username}
        </h2>
        <span className="text-xs font-bold text-gray-400 mt-1">
          FIELD AGENT
        </span>
      </div>

      {/* User Details Section */}
      {isEditing ? (
        <>
          <div className="bg-gray-50/50 border border-gray-100 rounded-[2rem] p-6 space-y-6 mb-6">
            <FieldGroup className="space-y-6">
              <Field>
                <FieldLabel className="text-[10px] font-black uppercase tracking-widest text-gray-400 mb-2 block">
                  Display Name
                </FieldLabel>
                <Input
                  value={formData.display_name}
                  onChange={(e) => handleChange("display_name", e.target.value)}
                  className="bg-white border-gray-100 rounded-xl h-12 font-bold"
                />
                {formData.display_name.trim() && (
                  <p className="mt-1.5 text-[11px] text-gray-400">
                    Username:{" "}
                    <span className="font-mono font-medium text-gray-600">
                      {deriveUsername(formData.display_name)}
                    </span>
                  </p>
                )}
              </Field>

              <Field>
                <FieldLabel className="text-[10px] font-black uppercase tracking-widest text-gray-400 mb-2 block">
                  System Username (auto-derived)
                </FieldLabel>
                <Input
                  value={deriveUsername(
                    formData.display_name || formData.username,
                  )}
                  disabled
                  className="bg-gray-50 border-gray-100 rounded-xl h-12 font-mono text-sm"
                />
              </Field>

              <Field>
                <FieldLabel className="text-[10px] font-black uppercase tracking-widest text-gray-400 mb-2 block">
                  Email Address
                </FieldLabel>
                <Input
                  value={formData.email}
                  onChange={(e) => handleChange("email", e.target.value)}
                  className="bg-white border-gray-100 rounded-xl h-12 font-bold"
                />
              </Field>

              <Field>
                <FieldLabel className="text-[10px] font-black uppercase tracking-widest text-gray-400 mb-2 block">
                  Contact number
                </FieldLabel>
                <Input
                  value={formData.contact}
                  onChange={(e) => handleChange("contact", e.target.value)}
                  className="bg-white border-gray-100 rounded-xl h-12 font-bold"
                />
              </Field>
            </FieldGroup>
          </div>

          <div className="mb-6">
            <StockFlowButton
              variant="filled"
              text={saving ? "Updating..." : "Update Details"}
              onClick={handleUpdate}
              disabled={saving}
              className="w-full h-14 rounded-2xl bg-primary text-white font-bold shadow-lg shadow-primary/20 flex items-center justify-center gap-2 active:scale-95 transition-all"
            />
          </div>
        </>
      ) : (
        <div className="bg-gray-50 border border-gray-100 rounded-2xl p-4 mb-6 w-full">
          <div className="space-y-3">
            <div className="flex justify-between items-center">
              <span className="text-xs font-bold text-gray-400 uppercase">
                Display Name
              </span>
              <span className="text-sm font-medium text-gray-900">
                {agent.user.display_name || "—"}
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-xs font-bold text-gray-400 uppercase">
                Username
              </span>
              <span className="text-sm font-medium text-gray-900">
                {agent.user.username}
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-xs font-bold text-gray-400 uppercase">
                Email
              </span>
              <span className="text-sm font-medium text-gray-900">
                {agent.user.email}
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-xs font-bold text-gray-400 uppercase">
                Contact
              </span>
              <span className="text-sm font-medium text-gray-900">
                {agent.contact || "—"}
              </span>
            </div>
          </div>
        </div>
      )}

      <ItemAssignment
        agentId={parseInt(id as string, 10)}
        agentName={agent?.user.display_name || agent?.user.username || ""}
        items={items}
        selectedVariantIds={selectedVariantIds}
        savedVariantIds={savedVariantIds}
        variantCreatedAt={variantCreatedAt}
        onToggleVariant={toggleVariant}
        onSaveItems={handleSaveItems}
        savingItems={savingItems}
        hasChanges={hasChanges}
      />
    </div>
  );
}
