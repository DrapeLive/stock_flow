import React from "react";

interface StockFlowButtonProps {
  variant?: "filled" | "outline";
  text: string;
  icon?: React.ReactNode;
  onClick?: () => void;
  className?: string;
  disabled?: boolean;
}

const StockFlowButton: React.FC<StockFlowButtonProps> = ({
  variant = "filled",
  text,
  icon,
  onClick,
  className = "",
  disabled = false,
}) => {
  const baseStyles =
    "flex items-center gap-1 px-3 py-3 font-medium text-sm rounded-[var(--radius)] transition-all";

  const variants = {
    filled: `
      ${baseStyles}
      bg-[var(--color-primary)]
      ${disabled ? "text-gray" : "text-white"}
      hover:brightness-110
    `,
    outline: `
      ${baseStyles}
      border border-[var(--color-primary)]
      text-[var(--color-primary)]
      bg-white
      hover:bg-[var(--color-primary)] hover:text-white
    `,
  };

  return (
    <button className={`${variants[variant]} ${className}`} onClick={onClick}>
      {text}
      {icon && <span className="text-current">{icon}</span>}
    </button>
  );
};

export default StockFlowButton;
