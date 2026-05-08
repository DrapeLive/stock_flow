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
    if (preventNavigation) {
      window.history.pushState(null, "", window.location.href);
    }

    const handlePopState = () => {
      onBack();

      if (preventNavigation) {
        window.history.pushState(null, "", window.location.href);
      }
    };

    window.addEventListener("popstate", handlePopState);

    return () => {
      window.removeEventListener("popstate", handlePopState);
    };
  }, [onBack, preventNavigation]);
}
