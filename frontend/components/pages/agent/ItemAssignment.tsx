"use client";

import { useState, useMemo } from "react";
import { Item } from "@/types/item";
import { ImagePreview } from "@/components/pages/ImagePreview";
import { toastSuccess, toastError } from "@/lib/toast";
import { Package, X, Scan } from "lucide-react";
import QRScanModal from "@/components/items/QRScanModal";

type Tab = "Recent" | "Assigned";

interface ItemAssignmentProps {
    agentId: number;
    items: Item[];
    selectedItemIds: number[];
    savedItemIds: number[];
    onToggleItem: (itemId: number) => void;
    onSaveItems: () => void;
    savingItems: boolean;
    hasChanges: boolean;
}

export default function ItemAssignment({
    agentId,
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

                <button
                    onClick={() => setShowQRScanner(true)}
                    className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-white border border-gray-200 rounded-md hover:bg-gray-50 active:scale-[0.98] transition-all mb-3"
                >
                    <Scan size={18} className="text-gray-600" />
                    <span className="font-bold text-sm text-gray-700">
                        Scan QR
                    </span>
                </button>

                {selectedItemIds.length > 0 && (
                    <div className="bg-gray-100/50 p-1.5 flex items-center space-x-1 border border-gray-200 rounded-md mb-4">
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
                )}

                {displayCount > 0 ? (
                    <div className="flex gap-2 flex-wrap">
                        {displayItems.map((item) => (
                            <button
                                key={item.id}
                                onClick={() => onToggleItem(item.id)}
                                className="relative flex-shrink-0 w-16 h-16 rounded-xl border-2 border-primary bg-white overflow-hidden active:scale-95 transition-all group"
                            >
                                {item.variants?.[0]?.image ? (
                                    <ImagePreview
                                        enlargeDisabled={true}
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
                                <div className="absolute inset-0 bg-red-500/80 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity rounded-xl">
                                    <X size={16} className="text-white" />
                                </div>
                            </button>
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
