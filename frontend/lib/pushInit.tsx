"use client";

import { useEffect } from "react";
import { api } from "@/lib/api";
import {
  registerServiceWorker,
  askNotificationPermission,
  subscribeUser,
} from "@/lib/push";

export default function PushNotificationInit() {
  useEffect(() => {
    async function initPush() {
      try {
        await registerServiceWorker();
        await askNotificationPermission();

        const subscription = await subscribeUser();

        await api.post("/api/notification/save-subscription/", subscription);

        console.log("Push subscription saved");
      } catch (error) {
        console.error("Push notification error:", error);
      }
    }

    initPush();
  }, []);

  return null;
}
