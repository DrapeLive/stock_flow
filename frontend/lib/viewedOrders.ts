const STORAGE_KEY = "viewed_orders";

function getViewedOrders(): Set<number> {
  if (typeof window === "undefined") return new Set();
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (!stored) return new Set();
    return new Set(JSON.parse(stored) as number[]);
  } catch {
    return new Set();
  }
}

function saveViewedOrders(viewed: Set<number>) {
  if (typeof window === "undefined") return;
  localStorage.setItem(STORAGE_KEY, JSON.stringify([...viewed]));
}

export function markOrderAsViewed(orderId: number) {
  const viewed = getViewedOrders();
  viewed.add(orderId);
  saveViewedOrders(viewed);
}

export function isOrderViewed(orderId: number): boolean {
  return getViewedOrders().has(orderId);
}

export function getViewedOrdersCount(orderIds: number[]): number {
  const viewed = getViewedOrders();
  return orderIds.filter((id) => !viewed.has(id)).length;
}

export function markOrderAsUnread(orderId: number) {
  const viewed = getViewedOrders();
  viewed.delete(orderId);
  saveViewedOrders(viewed);
}

export function markAllAsUnread() {
  if (typeof window === "undefined") return;
  localStorage.removeItem(STORAGE_KEY);
}

export function markAllAsRead(orderIds: number[]) {
  if (typeof window === "undefined") return;
  const viewed = getViewedOrders();
  orderIds.forEach(id => viewed.add(id));
  saveViewedOrders(viewed);
}

export function getUnreadIds(orderIds: number[]): number[] {
  const viewed = getViewedOrders();
  return orderIds.filter((id) => !viewed.has(id));
}
