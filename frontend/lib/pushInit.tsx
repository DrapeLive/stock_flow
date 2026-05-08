"use client";
import { useEffect } from "react";
import {
  registerServiceWorker,
  askNotificationPermission,
  subscribeUser,
} from "@/lib/push";

function getCookie(name: string): string {
  const match = document.cookie.match(new RegExp("(^| )" + name + "=([^;]+)"));
  return match ? match[2] : "";
}

export default function PushNotificationInit() {
  useEffect(() => {
    async function initPush() {
      try {
        await registerServiceWorker(); // now waits for SW to be active
        await askNotificationPermission();

        const subscription = await subscribeUser();

        const res = await fetch(
          "http://localhost:8000/api/notification/save-subscription/",
          {
            method: "POST",
            credentials: "include",
            headers: {
              "Content-Type": "application/json",
              "X-CSRFToken": getCookie("csrftoken"), // double-check your cookie name
              Authorization: `Bearer ${getCookie("token")}`,
            },
            body: JSON.stringify(subscription),
          },
        );

        if (!res.ok) {
          throw new Error(`Server rejected subscription: ${res.status}`);
        }

        console.log("Push subscription saved");
      } catch (error) {
        console.error("Push notification error:", error);
      }
    }

    initPush();
  }, []);

  return null;
}
