export async function registerServiceWorker() {
  if ("serviceWorker" in navigator) {
    return navigator.serviceWorker.register("/sw.js");
  }
}

export async function askNotificationPermission() {
  const permission = await Notification.requestPermission();

  if (permission !== "granted") {
    throw new Error("Permission not granted");
  }
}

function urlBase64ToUint8Array(base64String: string) {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);

  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");

  const rawData = window.atob(base64);

  return Uint8Array.from([...rawData].map((char) => char.charCodeAt(0)));
}
export async function subscribeUser() {
  const publicVapidKey = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
  if (!publicVapidKey) {
    throw new Error("NEXT_PUBLIC_VAPID_PUBLIC_KEY is missing");
  }

  const registration = await navigator.serviceWorker.ready;

  const existingSubscription = await registration.pushManager.getSubscription();
  if (existingSubscription) {
    await existingSubscription.unsubscribe();
  }

  const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(publicVapidKey),
  });

  return subscription;
}
