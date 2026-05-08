"use client";

import React, {
  useState,
  useRef,
  useCallback,
  ChangeEvent,
  DragEvent,
} from "react";
import * as XLSX from "xlsx";
import { customerApi } from "@/lib/api/customer";
import type { BulkCustomerRequest } from "@/types/customer";
import {
  ArrowLeft,
  Upload,
  Plus,
  Trash2,
  FileSpreadsheet,
  CheckCircle,
  AlertCircle,
} from "lucide-react";
import { useRouter } from "next/navigation";

type Status = "idle" | "parsing" | "ready" | "saving" | "success" | "error";
type ToastType = "info" | "success" | "error";

interface CustomerRow extends BulkCustomerRequest {
  _id: string;
}

interface ColumnDef {
  key: keyof BulkCustomerRequest;
  label: string;
  required: boolean;
  placeholder: string;
}

interface Toast {
  msg: string;
  type: ToastType;
}

type RowErrors = Partial<Record<keyof BulkCustomerRequest, boolean>>;
type ErrorMap = Record<string, RowErrors>;

const COLUMNS: ColumnDef[] = [
  {
    key: "name",
    label: "Customer Name",
    required: true,
    placeholder: "John Doe",
  },
  {
    key: "address",
    label: "Address",
    required: true,
    placeholder: "123 Main St…",
  },
  {
    key: "contact",
    label: "Contact",
    required: true,
    placeholder: "+91 98765 43210",
  },
  {
    key: "agent",
    label: "Agent",
    required: true,
    placeholder: "agent username",
  },
  {
    key: "gst",
    label: "GST No.",
    required: false,
    placeholder: "22AAAAA0000A1Z5",
  },
];

const uid = (): string => Math.random().toString(36).slice(2, 9);

const emptyRow = (): CustomerRow => ({
  _id: uid(),
  name: "",
  address: "",
  contact: "",
  agent: "",
  gst: "",
});

function normalizeRow(raw: Record<string, unknown>): BulkCustomerRequest {
  const lower: Record<string, string> = {};
  Object.keys(raw).forEach(
    (k) => (lower[k.toLowerCase().trim()] = String(raw[k] ?? "")),
  );
  return {
    name: lower["name"] ?? lower["customer name"] ?? "",
    address: lower["address"] ?? "",
    contact: lower["contact"] ?? lower["phone"] ?? lower["mobile"] ?? "",
    agent: lower["agent"] ?? lower["agent name"] ?? "",
    gst: lower["gst"] ?? lower["gst no"] ?? lower["gstin"] ?? "",
  };
}

const EditableCell: React.FC<{
  value: string;
  onChange: (val: string) => void;
  placeholder?: string;
  hasError: boolean;
}> = ({ value, onChange, placeholder, hasError }) => (
  <input
    type="text"
    value={value}
    onChange={(e: ChangeEvent<HTMLInputElement>) => onChange(e.target.value)}
    placeholder={placeholder}
    className={`w-full min-w-[90px] bg-transparent rounded-xl px-3 py-2 text-sm text-gray-800
      placeholder:text-gray-300 outline-none transition-all duration-150 border
      ${
        hasError
          ? "border-rose-300 bg-rose-50 focus:border-rose-400"
          : "border-gray-100 focus:border-primary/40 focus:bg-gray-50 hover:border-gray-200"
      }`}
  />
);

export default function BulkImportPage(): React.ReactElement {
  const router = useRouter();
  const [rows, setRows] = useState<CustomerRow[]>([]);
  const [status, setStatus] = useState<Status>("idle");
  const [toast, setToast] = useState<Toast | null>(null);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [fileName, setFileName] = useState<string>("");
  const [dragOver, setDragOver] = useState<boolean>(false);
  const [errors, setErrors] = useState<ErrorMap>({});
  const fileRef = useRef<HTMLInputElement>(null);

  const showToast = useCallback((msg: string, type: ToastType = "info") => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3500);
  }, []);

  const validate = useCallback((rowList: CustomerRow[]): ErrorMap => {
    const errs: ErrorMap = {};
    rowList.forEach((r) => {
      const rowErr: RowErrors = {};
      COLUMNS.forEach((c) => {
        if (c.required && !r[c.key].trim()) rowErr[c.key] = true;
      });
      if (Object.keys(rowErr).length) errs[r._id] = rowErr;
    });
    return errs;
  }, []);

  const parseFile = useCallback(
    (file: File | null | undefined) => {
      if (!file) return;
      const ext = file.name.split(".").pop()?.toLowerCase();
      if (!["xlsx", "xls", "csv"].includes(ext ?? "")) {
        showToast("Only .xlsx, .xls or .csv files supported", "error");
        return;
      }
      setFileName(file.name);
      setStatus("parsing");
      const reader = new FileReader();
      reader.onload = (e) => {
        try {
          const wb = XLSX.read(e.target?.result as string, { type: "binary" });
          const ws = wb.Sheets[wb.SheetNames[0]];
          const json = XLSX.utils.sheet_to_json<Record<string, unknown>>(ws, {
            defval: "",
          });
          const parsed: CustomerRow[] = json.map((r) => ({
            _id: uid(),
            ...normalizeRow(r),
          }));
          setRows(parsed);
          setErrors(validate(parsed));
          setSelected(new Set());
          setStatus("ready");
          showToast(`${parsed.length} rows loaded`, "success");
        } catch {
          setStatus("error");
          showToast("Failed to parse file — check the format.", "error");
        }
      };
      reader.readAsBinaryString(file);
    },
    [validate, showToast],
  );

  const handleDrop = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setDragOver(false);
    parseFile(e.dataTransfer.files[0]);
  };

  const updateCell = (
    id: string,
    col: keyof BulkCustomerRequest,
    val: string,
  ) => {
    setRows((prev) => {
      const next = prev.map((r) => (r._id === id ? { ...r, [col]: val } : r));
      setErrors(validate(next));
      return next;
    });
  };

  const deleteRow = (id: string) => {
    setRows((p) => p.filter((r) => r._id !== id));
    setSelected((s) => {
      const n = new Set(s);
      n.delete(id);
      return n;
    });
  };
  const deleteSelected = () => {
    setRows((p) => p.filter((r) => !selected.has(r._id)));
    setSelected(new Set());
  };
  const addRow = () => setRows((p) => [...p, emptyRow()]);
  const toggleSelect = (id: string) =>
    setSelected((s) => {
      const n = new Set(s);
      n.has(id) ? n.delete(id) : n.add(id);
      return n;
    });
  const toggleAll = () =>
    setSelected(
      selected.size === rows.length
        ? new Set()
        : new Set(rows.map((r) => r._id)),
    );
  const clearAll = () => {
    setRows([]);
    setFileName("");
    setStatus("idle");
    setErrors({});
    setSelected(new Set());
  };

  const handleConfirm = async () => {
    const errs = validate(rows);
    if (Object.keys(errs).length) {
      setErrors(errs);
      showToast(
        `Fix ${Object.keys(errs).length} invalid row(s) before saving`,
        "error",
      );
      return;
    }
    setStatus("saving");
    const payload: BulkCustomerRequest[] = rows.map(({ _id, ...rest }) => rest);
    try {
      const result = await customerApi.bulkImport({ customers: payload });
      if (result.failed > 0) {
        setStatus("error");
        showToast(`${result.created} saved, ${result.failed} failed.`, "error");
      } else {
        setStatus("success");
        showToast(`${result.created} customers saved successfully!`, "success");
      }
    } catch (err: unknown) {
      setStatus("error");
      showToast(
        "Save failed: " +
          (err instanceof Error ? err.message : "Unknown error"),
        "error",
      );
    }
  };

  const errorCount = Object.keys(errors).length;
  const allSelected = rows.length > 0 && selected.size === rows.length;

  return (
    <div className="min-h-screen py-10 px-6">
      {toast && (
        <div
          className={`fixed top-5 right-5 z-50 max-w-sm px-5 py-4 rounded-2xl border shadow-lg text-sm font-semibold flex items-center gap-2
          ${
            toast.type === "error"
              ? "bg-rose-50 border-rose-200 text-rose-600"
              : toast.type === "success"
                ? "bg-green-50 border-green-200 text-green-700"
                : "bg-white border-gray-100 text-gray-700"
          }`}
        >
          {toast.type === "error" ? (
            <AlertCircle size={16} />
          ) : (
            <CheckCircle size={16} />
          )}
          {toast.msg}
        </div>
      )}

      <div className="max-w-5xl mx-auto">
        <button
          onClick={() => router.push("/admin/profile")}
          className="flex items-center gap-2 text-sm font-bold text-gray-400 hover:text-gray-700 mb-8 transition-colors"
        >
          <ArrowLeft size={18} />
        </button>

        {/* Header */}
        <div className="text-center mb-10">
          <div className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-primary/10 text-primary mb-4 shadow-sm border border-primary/5">
            <Upload size={36} />
          </div>
          <h1 className="text-2xl font-black text-gray-900 leading-tight">
            Bulk Import
          </h1>
          <p className="text-xs text-gray-400 font-bold uppercase tracking-widest mt-1">
            Upload · Review · Save
          </p>
        </div>

        {/* Upload Zone */}
        <div
          onDragOver={(e: DragEvent<HTMLDivElement>) => {
            e.preventDefault();
            setDragOver(true);
          }}
          onDragLeave={() => setDragOver(false)}
          onDrop={handleDrop}
          onClick={() => fileRef.current?.click()}
          className={`bg-white rounded-3xl border-2 border-dashed cursor-pointer transition-all duration-200 text-center mb-6 shadow-sm
            ${
              dragOver
                ? "border-primary bg-primary/5"
                : fileName
                  ? "border-gray-200 hover:border-primary/40"
                  : "border-gray-200 hover:border-gray-300"
            }`}
          style={{ padding: fileName ? "28px 24px" : "48px 24px" }}
        >
          <input
            ref={fileRef}
            type="file"
            accept=".xlsx,.xls,.csv"
            className="hidden"
            onChange={(e: ChangeEvent<HTMLInputElement>) =>
              parseFile(e.target.files?.[0])
            }
          />

          {fileName ? (
            <div className="flex items-center justify-center gap-4 flex-wrap">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-blue-50 text-blue-500 flex items-center justify-center">
                  <FileSpreadsheet size={20} />
                </div>
                <div className="text-left">
                  <p className="text-gray-800 font-bold text-sm">{fileName}</p>
                  <p className="text-gray-400 text-xs mt-0.5">
                    {rows.length} rows loaded · Click to replace
                  </p>
                </div>
              </div>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  clearAll();
                }}
                className="ml-auto text-xs font-bold text-rose-400 bg-rose-50 border border-rose-100 rounded-2xl px-4 py-2 hover:bg-rose-100 transition-all"
              >
                Clear
              </button>
            </div>
          ) : (
            <>
              <div className="w-14 h-14 rounded-full bg-gray-100 flex items-center justify-center mx-auto mb-4 text-gray-400">
                <Upload size={24} />
              </div>
              <p className="text-base font-bold text-gray-700">
                Drop your spreadsheet here
              </p>
              <p className="text-gray-400 text-sm mt-1">
                or click to browse — .xlsx, .xls, .csv
              </p>
              <p className="text-xs text-gray-300 font-semibold uppercase tracking-wider mt-4">
                Name · Address · Contact · Agent · GST No.
              </p>
            </>
          )}
        </div>

        {/* Table Section */}
        {rows.length > 0 && (
          <div>
            {/* Toolbar */}
            <div className="flex items-center gap-3 flex-wrap mb-4">
              <div className="flex items-center gap-2 text-sm">
                <span className="text-gray-500 font-bold">
                  {rows.length} rows
                </span>
                {selected.size > 0 && (
                  <span className="text-primary bg-primary/10 rounded-full px-3 py-0.5 text-xs font-black">
                    {selected.size} selected
                  </span>
                )}
                {errorCount > 0 && (
                  <span className="text-rose-500 bg-rose-50 border border-rose-100 rounded-full px-3 py-0.5 text-xs font-black">
                    {errorCount} invalid
                  </span>
                )}
              </div>
              <div className="ml-auto flex items-center gap-2 flex-wrap">
                {selected.size > 0 && (
                  <button
                    onClick={deleteSelected}
                    className="flex items-center gap-1.5 text-xs font-bold text-rose-500 bg-rose-50 border border-rose-100 hover:bg-rose-100 rounded-2xl px-4 py-2 transition-all"
                  >
                    <Trash2 size={14} /> Delete {selected.size}
                  </button>
                )}
                <button
                  onClick={addRow}
                  className="flex items-center gap-1.5 text-xs font-bold text-gray-600 bg-white border border-gray-200 hover:border-gray-300 rounded-2xl px-4 py-2 transition-all shadow-sm"
                >
                  <Plus size={14} /> Add Row
                </button>
                <button
                  onClick={handleConfirm}
                  disabled={status === "saving"}
                  className={`text-sm font-black rounded-2xl px-6 py-2 transition-all
                    ${
                      errorCount > 0
                        ? "bg-rose-50 text-rose-400 border border-rose-100 cursor-not-allowed"
                        : status === "saving"
                          ? "bg-primary/50 text-white cursor-wait"
                          : "bg-primary text-white shadow-md hover:opacity-90 active:scale-95"
                    }`}
                >
                  {status === "saving"
                    ? "Saving…"
                    : errorCount > 0
                      ? `Fix ${errorCount} error(s)`
                      : `Save ${rows.length} Customers`}
                </button>
              </div>
            </div>

            {/* Table */}
            <div className="bg-white rounded-3xl border border-gray-100 shadow-sm overflow-hidden">
              <div className="overflow-x-auto">
                <table className="w-full border-collapse text-sm">
                  <thead>
                    <tr className="border-b border-gray-100">
                      <th className="px-4 py-3.5 w-10 text-center">
                        <input
                          type="checkbox"
                          checked={allSelected}
                          onChange={toggleAll}
                          className="w-4 h-4 rounded accent-primary cursor-pointer"
                        />
                      </th>
                      <th className="px-3 py-3.5 w-10 text-left text-gray-300 text-xs font-black tracking-widest uppercase">
                        #
                      </th>
                      {COLUMNS.map((col) => (
                        <th
                          key={col.key}
                          className="px-3 py-3.5 text-left text-xs font-black tracking-widest uppercase text-gray-400 whitespace-nowrap"
                        >
                          {col.label}
                          {col.required && (
                            <span className="text-primary ml-1">*</span>
                          )}
                        </th>
                      ))}
                      <th className="px-4 py-3.5 w-16 text-center text-xs font-black tracking-widest uppercase text-gray-300"></th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((row, idx) => {
                      const rowErrors: RowErrors = errors[row._id] ?? {};
                      const hasError = Object.keys(rowErrors).length > 0;
                      return (
                        <tr
                          key={row._id}
                          className={`border-b border-gray-50 transition-colors
                            ${selected.has(row._id) ? "bg-primary/5" : idx % 2 === 0 ? "bg-white" : "bg-gray-50/50"}
                            hover:bg-gray-50
                            ${hasError ? "border-l-2 border-l-rose-400" : "border-l-2 border-l-transparent"}`}
                        >
                          <td className="px-4 py-2 text-center">
                            <input
                              type="checkbox"
                              checked={selected.has(row._id)}
                              onChange={() => toggleSelect(row._id)}
                              className="w-4 h-4 rounded accent-primary cursor-pointer"
                            />
                          </td>
                          <td className="px-3 py-2 text-gray-300 text-xs font-bold select-none">
                            {idx + 1}
                          </td>
                          {COLUMNS.map((col) => (
                            <td key={col.key} className="px-1.5 py-1.5">
                              <EditableCell
                                value={row[col.key]}
                                onChange={(v) =>
                                  updateCell(row._id, col.key, v)
                                }
                                placeholder={col.placeholder}
                                hasError={!!rowErrors[col.key]}
                              />
                            </td>
                          ))}
                          <td className="px-4 py-2 text-center">
                            <button
                              onClick={() => deleteRow(row._id)}
                              className="text-gray-300 hover:text-rose-400 hover:bg-rose-50 rounded-xl w-8 h-8 flex items-center justify-center mx-auto transition-all"
                            >
                              <Trash2 size={14} />
                            </button>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
              <div className="border-t border-gray-100 px-5 py-3 flex items-center justify-between text-xs text-gray-400 font-semibold">
                <span>
                  Fields marked{" "}
                  <span className="text-primary font-black">*</span> are
                  required · Click any cell to edit
                </span>
                <span>{rows.length} rows total</span>
              </div>
            </div>

            {/* Bottom Actions */}
            <div className="mt-5 flex justify-end items-center gap-3 px-1">
              <button
                onClick={clearAll}
                className="text-sm font-black text-gray-400 hover:text-gray-600 border border-gray-200 bg-white rounded-3xl px-6 py-3 transition-all shadow-sm"
              >
                Cancel
              </button>
              <button
                onClick={handleConfirm}
                disabled={status === "saving"}
                className={`text-sm font-black rounded-3xl px-8 py-3 transition-all
                  ${
                    errorCount > 0
                      ? "bg-rose-50 text-rose-400 border border-rose-100 cursor-not-allowed"
                      : status === "saving"
                        ? "bg-primary/50 text-white cursor-wait"
                        : "bg-primary text-white shadow-md hover:opacity-90 active:scale-95"
                  }`}
              >
                {status === "saving"
                  ? "Saving…"
                  : errorCount > 0
                    ? `Fix ${errorCount} error(s) first`
                    : `✓ Save ${rows.length} Customers`}
              </button>
            </div>
          </div>
        )}

        {/* Empty State */}
        {rows.length === 0 && status === "idle" && (
          <div className="mt-10 text-center space-y-2">
            <div className="w-16 h-16 rounded-full bg-gray-100 flex items-center justify-center mx-auto text-gray-300">
              <FileSpreadsheet size={28} />
            </div>
            <p className="text-gray-400 font-bold text-sm mt-3">
              Upload a spreadsheet to get started
            </p>
          </div>
        )}

        {/* Column Reference */}
        <details className="mt-10 group">
          <summary className="cursor-pointer text-xs text-gray-400 hover:text-gray-600 transition-colors select-none list-none flex items-center gap-2 font-bold">
            <span className="group-open:rotate-90 transition-transform inline-block">
              ›
            </span>
            Expected column names
          </summary>
          <div className="mt-3 bg-white border border-gray-100 rounded-3xl p-5 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 shadow-sm">
            {[
              { sheet: "name / customer name", field: "Name *" },
              { sheet: "address", field: "Address *" },
              { sheet: "contact / phone / mobile", field: "Contact *" },
              { sheet: "agent / agent name", field: "Agent *" },
              { sheet: "gst / gst no / gstin", field: "GST No." },
            ].map((m) => (
              <div key={m.field} className="text-xs flex items-center gap-2">
                <code className="text-primary bg-primary/8 border border-primary/10 rounded-lg px-2 py-1 font-mono text-[11px]">
                  {m.sheet}
                </code>
                <span className="text-gray-300">→</span>
                <span className="text-gray-500 font-bold">{m.field}</span>
              </div>
            ))}
          </div>
        </details>
      </div>
    </div>
  );
}
