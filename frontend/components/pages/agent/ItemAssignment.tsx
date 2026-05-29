"use client";

import { useState, useMemo, useCallback } from "react";
import { Item } from "@/types/item";
import { ImagePreview } from "@/components/pages/ImagePreview";
import { toastSuccess, toastError } from "@/lib/toast";
import { Package, Trash2, Scan, Download } from "lucide-react";
import { pdf } from "@react-pdf/renderer";
import AssignedItemsPDF from "@/components/pages/agent/AssignedItemsPDF";
import type { PDFItem } from "@/components/pages/agent/AssignedItemsPDF";
import QRScanModal from "@/components/items/QRScanModal";

type Tab = "Recent" | "Assigned";

interface ItemAssignmentProps {
    agentId: number;
    agentName: string;
    items: Item[];
    selectedItemIds: number[];
    savedItemIds: number[];
    onToggleItem: (itemId: number) => void;
    onSaveItems: () => void;
    savingItems: boolean;
    hasChanges: boolean;
}

const urlToDataUrl = async (url: string): Promise<string | null> => {
    try {
        const res = await fetch(url, { mode: "cors" });
        if (!res.ok) return null;
        const blob = await res.blob();
        return await new Promise((resolve) => {
            const img = new Image();
            const objectUrl = URL.createObjectURL(blob);
            img.onload = () => {
                const canvas = document.createElement("canvas");
                canvas.width = img.naturalWidth;
                canvas.height = img.naturalHeight;
                const ctx = canvas.getContext("2d")!;
                ctx.clearRect(0, 0, canvas.width, canvas.height);
                ctx.drawImage(img, 0, 0);
                URL.revokeObjectURL(objectUrl);
                resolve(canvas.toDataURL("image/png"));
            };
            img.onerror = () => {
                URL.revokeObjectURL(objectUrl);
                resolve(null);
            };
            img.src = objectUrl;
        });
    } catch {
        return null;
    }
};

export default function ItemAssignment({
    agentId,
    agentName,
    items,
    selectedItemIds,
    savedItemIds,
    onToggleItem,
    onSaveItems,
    savingItems,
    hasChanges,
}: ItemAssignmentProps) {
    const [activeTab, setActiveTab] = useState<Tab>("Recent");
    const [showQRScanner, setShowQRScanner] = useState(false);
    const [generatingPDF, setGeneratingPDF] = useState(false);

    const recentIds = useMemo(
        () => selectedItemIds.filter((id) => !savedItemIds.includes(id)),
        [selectedItemIds, savedItemIds],
    );

    const assignedIds = useMemo(
        () => selectedItemIds.filter((id) => savedItemIds.includes(id)),
        [selectedItemIds, savedItemIds],
    );

    const recentItems = useMemo(
        () => items.filter((item) => recentIds.includes(item.id)),
        [items, recentIds],
    );

    const assignedItems = useMemo(
        () => items.filter((item) => assignedIds.includes(item.id)),
        [items, assignedIds],
    );

    const handleQRScan = (qr: string) => {
        const trimmed = qr.trim();
        const item = items.find(
            (i) =>
                i.variants?.some((v) => v.qr_code === trimmed) ||
                i.id.toString() === trimmed,
        );
        if (item) {
            if (!selectedItemIds.includes(item.id)) {
                onToggleItem(item.id);
                toastSuccess(`${item.name} added`);
            } else {
                toastSuccess(`${item.name} already selected`);
            }
            setShowQRScanner(false);
        } else {
            toastError("Item not found with this QR code");
            setShowQRScanner(false);
        }
    };

    const handleDownloadPDF = useCallback(async () => {
        setGeneratingPDF(true);
        try {
            const targetItems =
                activeTab === "Recent" ? recentItems : assignedItems;

            const pdfItems: PDFItem[] = await Promise.all(
                targetItems.map(async (item) => {
                    const imageUrl = item.variants?.[0]?.image ?? null;
                    const imageDataUrl = imageUrl
                        ? await urlToDataUrl(imageUrl)
                        : null;
                    return {
                        id: item.id,
                        name: item.name,
                        type: item.type,
                        price: item.price,
                        imageDataUrl,
                        variantCount: item.variants?.length ?? 0,
                    };
                }),
            );

            const now = new Date();
            const generatedAt = now.toLocaleDateString("en-IN", {
                year: "numeric",
                month: "short",
                day: "numeric",
                hour: "2-digit",
                minute: "2-digit",
            });

            const blob = await pdf(
                <AssignedItemsPDF
                    items={pdfItems}
                    agentName={agentName}
                    tabLabel={activeTab}
                    generatedAt={generatedAt}
                />,
            ).toBlob();

            const url = URL.createObjectURL(blob);
            const a = document.createElement("a");
            a.href = url;
            a.download = `assigned-items-${agentName.replace(/\s+/g, "-")}-${activeTab.toLowerCase()}.pdf`;
            a.click();
            setTimeout(() => URL.revokeObjectURL(url), 1000);
        } catch (e) {
            console.error("Failed to generate PDF:", e);
            toastError("Failed to generate PDF");
        } finally {
            setGeneratingPDF(false);
        }
    }, [activeTab, recentItems, assignedItems, agentName]);

    const displayItems = activeTab === "Recent" ? recentItems : assignedItems;
    const displayCount =
        activeTab === "Recent" ? recentItems.length : assignedItems.length;

    return (
        <>
            <div className="border-t border-gray-100 pt-6 mt-2">
                <div className="sticky top-0 z-10 bg-white pt-2 pb-3 -mt-2 mb-3 border-b border-gray-100">
                    <div className="flex items-center gap-2">
                        <div className="flex-1 flex items-center gap-2">
                            <h3 className="text-lg font-black text-gray-900">
                                Items
                            </h3>
                            <span className="text-xs font-bold text-primary bg-primary/10 px-2 py-0.5 rounded-md">
                                {selectedItemIds.length}
                            </span>
                            {hasChanges && (
                                <span className="text-xs font-bold text-amber-500 bg-amber-50 px-2 py-0.5 rounded-md">
                                    Unsaved
                                </span>
                            )}
                        </div>
                        <button
                            onClick={onSaveItems}
                            disabled={savingItems || !hasChanges}
                            className="flex items-center justify-center gap-1.5 px-6 py-3 bg-green-600 text-white rounded-md font-bold shadow-lg shadow-green-600/20 active:scale-95 transition-all disabled:opacity-50 min-w-[100px]"
                        >
                            {savingItems ? "Saving..." : "Save"}
                        </button>
                    </div>
                </div>

                <div className="flex gap-2 items-center justify-center">
                    <button
                        onClick={() => setShowQRScanner(true)}
                        className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-white border border-gray-200 rounded-md hover:bg-gray-50 active:scale-[0.98] transition-all mb-3"
                    >
                        <Scan size={18} className="text-gray-600" />
                        <span className="font-bold text-sm text-gray-700">
                            Scan QR
                        </span>
                    </button>
                    <button
                        onClick={handleDownloadPDF}
                        disabled={generatingPDF || displayCount === 0}
                        className="flex items-center justify-center gap-2 px-4 py-3 bg-white border border-gray-200 rounded-md hover:bg-gray-50 active:scale-[0.98] transition-all mb-3"
                        title="Download PDF"
                    >
                        <span className="flex gap-2 text-sm">
                            {generatingPDF ? (
                                <span className="w-4.5 h-4.5 border-2 border-gray-300 border-t-gray-500 rounded-full animate-spin block" />
                            ) : (
                                <Download size={18} />
                            )}{" "}
                            Summary
                        </span>
                    </button>
                </div>

                {selectedItemIds.length > 0 && (
                    <div className="flex items-center gap-2 mb-4">
                        <div className="flex-1 bg-gray-100/50 p-1.5 flex items-center space-x-1 border border-gray-200 rounded-md">
                            <button
                                onClick={() => setActiveTab("Recent")}
                                className={`flex-1 rounded-md py-2 font-bold text-xs transition-all ${
                                    activeTab === "Recent"
                                        ? "bg-primary text-white shadow-sm"
                                        : "text-gray-500 hover:text-gray-700"
                                }`}
                            >
                                Recent ({recentItems.length})
                            </button>
                            <button
                                onClick={() => setActiveTab("Assigned")}
                                className={`flex-1 rounded-md py-2 font-bold text-xs transition-all ${
                                    activeTab === "Assigned"
                                        ? "bg-primary text-white shadow-sm"
                                        : "text-gray-500 hover:text-gray-700"
                                }`}
                            >
                                Assigned ({assignedItems.length})
                            </button>
                        </div>
                    </div>
                )}

                {displayCount > 0 ? (
                    <div className="space-y-2">
                        {displayItems.map((item) => (
                            <div
                                key={item.id}
                                className="w-full flex items-center gap-3 p-2.5 rounded-md border-2 border-gray-100 bg-white"
                            >
                                <div className="w-10 h-10 rounded-md shrink-0 overflow-hidden ring-1 ring-gray-100">
                                    {item.variants?.[0]?.image ? (
                                        <ImagePreview
                                            src={item.variants[0].image}
                                            alt={item.name}
                                        />
                                    ) : (
                                        <div className="w-full h-full bg-gray-100 flex items-center justify-center">
                                            <Package
                                                size={16}
                                                className="text-gray-300"
                                            />
                                        </div>
                                    )}
                                </div>
                                <div className="flex-1 min-w-0">
                                    <p className="font-bold text-gray-900 text-sm truncate">
                                        {item.name}
                                    </p>
                                    <p className="text-xs text-gray-400 truncate">
                                        Rs. {item.price}
                                        {item.type && ` · ${item.type}`}
                                    </p>
                                </div>
                                <button
                                    onClick={() => onToggleItem(item.id)}
                                    className="flex items-center gap-1 px-3 py-2 rounded-xl text-red-500 hover:bg-red-50 active:scale-95 transition-all"
                                >
                                    <Trash2 size={16} />
                                    <span className="font-bold text-xs">
                                        Remove
                                    </span>
                                </button>
                            </div>
                        ))}
                    </div>
                ) : (
                    <p className="text-center text-gray-400 py-8 text-sm">
                        {activeTab === "Recent"
                            ? "No recently added items"
                            : "No assigned items"}
                    </p>
                )}
            </div>

            <QRScanModal
                isOpen={showQRScanner}
                onClose={() => setShowQRScanner(false)}
                onScan={handleQRScan}
            />

            <div className="h-20" />
        </>
    );
}

export type { Tab };
