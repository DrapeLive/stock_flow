"use client";

import { useEffect } from "react";

type BackHandlerOptions = {
  onBack: () => void;
  preventNavigation?: boolean;
};

export function useBackButton({
  onBack,
  preventNavigation = true,
}: BackHandlerOptions) {
  useEffect(() => {
    if (!preventNavigation) return;

    // Add one fake history entry
    window.history.pushState({ trap: true }, "");

    const handlePopState = () => {
      onBack();

      // Re-add history entry AFTER browser finishes navigation event
      setTimeout(() => {
        window.history.pushState({ trap: true }, "");
      }, 0);
    };

    window.addEventListener("popstate", handlePopState);

    return () => {
      window.removeEventListener("popstate", handlePopState);
    };
  }, [onBack, preventNavigation]);
}
