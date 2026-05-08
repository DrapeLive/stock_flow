export async function registerServiceWorker() {
  if (!("serviceWorker" in navigator)) {
    throw new Error("Service workers not supported");
  }
  const registration = await navigator.serviceWorker.register("/sw.js");
  await navigator.serviceWorker.ready;
  return registration;
}

export async function askNotificationPermission() {
  const permission = await Notification.requestPermission();
  if (permission !== "granted") {
    throw new Error(`Permission not granted: ${permission}`);
  }
}

function urlBase64ToUint8Array(base64String: string) {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
  const rawData = window.atob(base64);
  return Uint8Array.from([...rawData].map((char) => char.charCodeAt(0)));
}

function validateVapidKey(key: string): void {
  try {
    const bytes = urlBase64ToUint8Array(key);
    if (bytes.length !== 65) {
      throw new Error(
        `Invalid VAPID key length: ${bytes.length} (expected 65)`,
      );
    }
    if (bytes[0] !== 4) {
      throw new Error(
        `Invalid VAPID key format: first byte is ${bytes[0]} (expected 4)`,
      );
    }
  } catch (e) {
    throw new Error(`VAPID key validation failed: ${(e as Error).message}`);
  }
}

export async function subscribeUser() {
  const publicVapidKey = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;

  if (!publicVapidKey) {
    throw new Error("NEXT_PUBLIC_VAPID_PUBLIC_KEY is missing");
  }

  // Validate key format before even trying to subscribe
  validateVapidKey(publicVapidKey);

  const registration = await navigator.serviceWorker.ready;

  // Unsubscribe from any stale subscription first
  const existingSubscription = await registration.pushManager.getSubscription();
  if (existingSubscription) {
    await existingSubscription.unsubscribe();
  }

  try {
    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(publicVapidKey),
    });
    return subscription;
  } catch (err) {
    const error = err as DOMException;

    if (error.name === "AbortError") {
      // Wait 2 seconds and retry once — Firefox sometimes needs this
      // after unsubscribing a stale subscription
      await new Promise((resolve) => setTimeout(resolve, 2000));
      try {
        const retrySubscription = await registration.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: urlBase64ToUint8Array(publicVapidKey),
        });
        return retrySubscription;
      } catch (retryErr) {
        throw new Error(
          `Push subscription failed after retry. ` +
            `This is usually a Firefox/browser push service issue. ` +
            `Try: 1) Go to about:config and toggle dom.push.enabled off/on. ` +
            `2) Clear site data for localhost. ` +
            `Error: ${(retryErr as Error).message}`,
        );
      }
    }

    if (error.name === "NotAllowedError") {
      throw new Error(
        "Push subscription blocked — notification permission was denied.",
      );
    }

    if (error.name === "InvalidStateError") {
      throw new Error(
        "Service worker is not active yet. Please refresh the page.",
      );
    }

    throw err;
  }
}
