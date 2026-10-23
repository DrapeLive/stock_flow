"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ArrowLeft, Tags } from "lucide-react";

import { itemApi } from "@/lib/api/item";
import { toastError, toastSuccess } from "@/lib/toast";
import type { ItemCategory } from "@/types/item";

export default function ItemCategoriesPage() {
  const router = useRouter();
  const [categories, setCategories] = useState<ItemCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [newName, setNewName] = useState("");
  const [saving, setSaving] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editingName, setEditingName] = useState("");
  const [busyId, setBusyId] = useState<number | null>(null);

  useEffect(() => {
    let active = true;
    itemApi
      .getCategories()
      .then((data) => {
        if (active) setCategories(data);
      })
      .catch((error) => toastError("Failed to load categories", error))
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, []);

  const addCategory = async () => {
    const name = newName.trim();
    if (!name || saving) return;
    setSaving(true);
    try {
      await itemApi.createCategory(name);
      setNewName("");
      setCategories(await itemApi.getCategories());
      toastSuccess("Category added");
    } catch (error) {
      toastError("Could not add category", error);
    } finally {
      setSaving(false);
    }
  };

  const startEdit = (category: ItemCategory) => {
    setEditingId(category.id);
    setEditingName(category.name);
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditingName("");
  };

  const saveEdit = async (category: ItemCategory) => {
    const name = editingName.trim();
    if (!name || busyId !== null) return;
    if (name === category.name) {
      cancelEdit();
      return;
    }
    setBusyId(category.id);
    try {
      await itemApi.updateCategory(category.id, name);
      setCategories(await itemApi.getCategories());
      cancelEdit();
      toastSuccess("Category updated");
    } catch (error) {
      toastError("Could not update category", error);
    } finally {
      setBusyId(null);
    }
  };

  const deleteCategory = async (category: ItemCategory) => {
    if (
      !window.confirm(
        `Delete ${category.name}? Existing items keep their saved category.`,
      )
    ) {
      return;
    }
    setBusyId(category.id);
    try {
      await itemApi.deleteCategory(category.id);
      setCategories(await itemApi.getCategories());
      toastSuccess("Category deleted");
    } catch (error) {
      toastError("Could not delete category", error);
    } finally {
      setBusyId(null);
    }
  };

  return (
    <div className="min-h-screen bg-white">
      <div className="mx-auto max-w-lg px-4 py-8">
        <button
          onClick={() => router.push("/admin/profile?tab=settings")}
          aria-label="Back to settings"
          className="mb-4 -ml-2 rounded-xl p-2 text-gray-400 transition-colors hover:bg-gray-50"
        >
          <ArrowLeft size={22} />
        </button>

        <div className="mb-6">
          <p className="text-[10px] font-bold uppercase tracking-widest text-gray-400">
            Admin Settings
          </p>
          <h1 className="text-2xl font-black tracking-tight text-gray-900">
            Item Categories
          </h1>
          <p className="mt-1 text-sm font-medium text-gray-400">
            Manage the categories available when creating items.
          </p>
        </div>

        <form
          onSubmit={(event) => {
            event.preventDefault();
            void addCategory();
          }}
          className="mb-4 flex gap-2 rounded-3xl border border-gray-100 bg-gray-50/50 p-4"
        >
          <input
            value={newName}
            onChange={(event) => setNewName(event.target.value)}
            maxLength={100}
            placeholder="New category"
            className="min-w-0 flex-1 rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm outline-none focus:border-primary"
          />
          <button
            type="submit"
            disabled={!newName.trim() || saving}
            className="rounded-xl bg-primary px-4 py-2 text-sm font-bold text-white disabled:opacity-50"
          >
            {saving ? "Adding…" : "Add"}
          </button>
        </form>

        {loading ? (
          <div className="flex justify-center py-8">
            <div className="h-6 w-6 animate-spin rounded-full border-b-2 border-primary" />
          </div>
        ) : categories.length === 0 ? (
          <div className="flex flex-col items-center gap-1 py-8 text-center">
            <Tags size={22} className="text-gray-200" />
            <p className="text-xs font-bold text-gray-300">
              No categories yet
            </p>
          </div>
        ) : (
          <div className="divide-y divide-gray-100 rounded-3xl border border-gray-100 bg-white shadow-sm">
            {categories.map((category) => (
              <div
                key={category.id}
                className="flex items-center gap-2 px-4 py-3"
              >
                {editingId === category.id ? (
                  <>
                    <input
                      value={editingName}
                      onChange={(event) => setEditingName(event.target.value)}
                      maxLength={100}
                      autoFocus
                      className="min-w-0 flex-1 rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:border-primary"
                    />
                    <button
                      onClick={() => void saveEdit(category)}
                      disabled={
                        !editingName.trim() || busyId === category.id
                      }
                      className="rounded-lg px-3 py-1.5 text-xs font-bold text-primary hover:bg-primary/5 disabled:opacity-50"
                    >
                      Save
                    </button>
                    <button
                      onClick={cancelEdit}
                      disabled={busyId === category.id}
                      className="rounded-lg px-3 py-1.5 text-xs font-bold text-gray-400 hover:bg-gray-50"
                    >
                      Cancel
                    </button>
                  </>
                ) : (
                  <>
                    <span className="flex-1 text-sm font-bold text-gray-700">
                      {category.name}
                    </span>
                    <button
                      onClick={() => startEdit(category)}
                      disabled={busyId === category.id}
                      className="rounded-lg px-3 py-1.5 text-xs font-bold text-gray-400 hover:bg-gray-50 hover:text-primary"
                    >
                      Edit
                    </button>
                    <button
                      onClick={() => void deleteCategory(category)}
                      disabled={busyId === category.id}
                      className="rounded-lg px-3 py-1.5 text-xs font-bold text-rose-500 hover:bg-rose-50 disabled:opacity-50"
                    >
                      Delete
                    </button>
                  </>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
