"use client";

import { useEffect } from "react";

import { registerServiceWorker, subscribeUser } from "@/lib/push";

export default function PushNotificationInit() {
  useEffect(() => {
    async function initPush() {
      try {
        await registerServiceWorker();

        let permission = Notification.permission;

        if (permission === "default") {
          permission = await Notification.requestPermission();
        }

        if (permission !== "granted") {
          return;
        }

        const subscription = await subscribeUser();

        function getCookie(name: string): string {
          const match = document.cookie.match(
            new RegExp("(^| )" + name + "=([^;]+)"),
          );
          return match ? match[2] : "";
        }

        await fetch(
          "http://localhost:8000/api/notification/save-subscription/",
          {
            method: "POST",

            credentials: "include",

            headers: {
              "Content-Type": "application/json",
              "X-CSRFToken": getCookie("token"),
              Authorization: `Bearer ${getCookie("token")}`,
            },

            body: JSON.stringify(subscription),
          },
        );

        console.log("Push subscription saved");
      } catch (error) {
        console.error("Push notification error:", error);
      }
    }

    initPush();
  }, []);

  return null;
}
