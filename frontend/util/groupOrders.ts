import { OrderAllResponse } from "@/types/order";

const groupOrders = (orders: OrderAllResponse) => {
  return orders.reduce<{
    pendingPacked: OrderAllResponse;
    dispatched: OrderAllResponse;
  }>(
    (acc, order) => {
      if (order.status === "DISPATCHED") {
        acc.dispatched.push(order);
      } else {
        acc.pendingPacked.push(order);
      }

      return acc;
    },
    {
      pendingPacked: [],
      dispatched: [],
    },
  );
};

export default groupOrders;
