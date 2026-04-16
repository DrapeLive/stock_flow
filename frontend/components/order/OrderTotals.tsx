"use client";

interface OrderTotalsProps {
  totalSets: number;
  totalPieces: number;
  totalPrice: number;
  onPlaceOrder?: () => void;
  isLoading?: boolean;
  buttonText?: string;
  showButton?: boolean;
}

export default function OrderTotals({
  totalSets,
  totalPieces,
  totalPrice,
  onPlaceOrder,
  isLoading = false,
  buttonText = "Place Order",
  showButton = true,
}: OrderTotalsProps) {
  return (
    <div className="bg-gradient-to-r from-primary/5 to-primary/10 rounded-3xl p-5 border border-primary/20">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-[10px] text-primary/60 uppercase font-black tracking-widest">
            Order Total
          </p>
          <div className="flex items-center gap-4 mt-2">
            <div>
              <span className="text-2xl font-black text-gray-900">
                {totalSets}
              </span>
              <span className="text-sm text-gray-400 ml-1">Sets</span>
            </div>
            <span className="text-gray-300">•</span>
            <div>
              <span className="text-2xl font-black text-gray-900">
                {totalPieces}
              </span>
              <span className="text-sm text-gray-400 ml-1">pcs</span>
            </div>
            <span className="text-gray-300">•</span>
            <div>
              <span className="text-2xl font-black text-primary">
                ₹{totalPrice.toLocaleString("en-IN")}
              </span>
            </div>
          </div>
        </div>

        {showButton && onPlaceOrder && (
          <button
            onClick={onPlaceOrder}
            disabled={isLoading || totalSets === 0}
            className="flex items-center justify-center gap-2 bg-primary text-white font-bold py-3 px-5 rounded-2xl shadow-lg shadow-primary/30 hover:opacity-90 transition-all active:scale-95 disabled:opacity-50"
          >
            {isLoading ? (
              <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            ) : (
              <span>{buttonText}</span>
            )}
          </button>
        )}
      </div>
    </div>
  );
}
