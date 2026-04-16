"use client";

import { useState } from "react";
import { Scanner } from "@yudiel/react-qr-scanner";
import { X, Camera } from "lucide-react";

interface QRScanModalProps {
  isOpen: boolean;
  onClose: () => void;
  onScan: (qr: string) => void;
}

export default function QRScanModal({
  isOpen,
  onClose,
  onScan,
}: QRScanModalProps) {
  const [manualInput, setManualInput] = useState("");
  const [showManualInput, setShowManualInput] = useState(false);

  if (!isOpen) return null;

  const handleScan = (data: { rawValue: string }[]) => {
    if (data[0]?.rawValue) {
      onScan(data[0].rawValue);
    }
  };

  const handleManualSubmit = () => {
    if (manualInput.trim()) {
      onScan(manualInput.trim());
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div
        className="absolute inset-0 bg-black/80"
        onClick={onClose}
      />
      <div className="relative w-full max-w-sm mx-4 bg-white rounded-3xl overflow-hidden shadow-2xl">
        <div className="flex items-center justify-between p-4 border-b border-gray-100">
          <div className="flex items-center gap-2">
            <Camera className="text-primary" size={20} />
            <span className="font-bold text-gray-900">Scan QR Code</span>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-xl transition-colors"
          >
            <X size={20} className="text-gray-400" />
          </button>
        </div>

        <div className="p-4">
          <div className="relative aspect-square rounded-2xl overflow-hidden bg-gray-900 mb-4">
            <Scanner
              onScan={handleScan}
              constraints={{
                facingMode: "environment",
              }}
              styles={{
                container: { width: "100%", height: "100%" },
                video: { width: "100%", height: "100%", objectFit: "cover" },
              }}
              components={{
                torch: false,
              }}
            />
          </div>

          <button
            onClick={() => setShowManualInput(!showManualInput)}
            className="w-full text-center text-sm text-gray-500 hover:text-primary transition-colors py-2"
          >
            {showManualInput ? "Hide manual input" : "Or enter QR manually"}
          </button>

          {showManualInput && (
            <div className="mt-3 flex gap-2">
              <input
                type="text"
                placeholder="Enter QR code..."
                value={manualInput}
                onChange={(e) => setManualInput(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleManualSubmit()}
                className="flex-1 px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl text-sm font-medium text-gray-900 placeholder:text-gray-400 focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary/20"
              />
              <button
                onClick={handleManualSubmit}
                disabled={!manualInput.trim()}
                className="px-6 py-3 bg-primary text-white rounded-xl font-bold text-sm hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Go
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
