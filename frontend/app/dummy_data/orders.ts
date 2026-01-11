
export interface Item {
  id: number;
  quantity: number;
  packed_quantity: number;
  selected_color: string;
  selected_size: string;
  order: number;
  item: number;
}

export interface Order {
    id: number;
    items: Item[];
    status: string;
    created_at: string;
    customer: number;
    agent: number;
}

export const order: Order[] = [
  {
    "id": 1,
    "items": [
      {
        "id": 1,
        "quantity": 2000,
        "packed_quantity": 0,
        "selected_color": "blue",
        "selected_size": "XL",
        "order": 1,
        "item": 1
      }
    ],
    "status": "PACKED",
    "created_at": "2025-12-24T05:00:55.561269Z",
    "customer": 1,
    "agent": 1
  },
  {
    "id": 2,
    "items": [
      {
        "id": 3,
        "quantity": 200,
        "packed_quantity": 0,
        "selected_color": "red",
        "selected_size": "L",
        "order": 1,
        "item": 2
      }
    ],
    "status": "PENDING",
    "created_at": "2025-12-24T05:00:55.561269Z",
    "customer": 1,
    "agent": 1
  },
  {
    "id": 1,
    "items": [
      {
        "id": 1,
        "quantity": 2000,
        "packed_quantity": 0,
        "selected_color": "blue",
        "selected_size": "XL",
        "order": 1,
        "item": 1
      }
    ],
    "status": "PACKED",
    "created_at": "2025-12-24T05:00:55.561269Z",
    "customer": 1,
    "agent": 1
  },
  {
    "id": 1,
    "items": [
      {
        "id": 1,
        "quantity": 2000,
        "packed_quantity": 0,
        "selected_color": "blue",
        "selected_size": "XL",
        "order": 1,
        "item": 1
      }
    ],
    "status": "PACKED",
    "created_at": "2025-12-24T05:00:55.561269Z",
    "customer": 1,
    "agent": 1
  },
  {
    "id": 1,
    "items": [
      {
        "id": 1,
        "quantity": 2000,
        "packed_quantity": 0,
        "selected_color": "blue",
        "selected_size": "XL",
        "order": 1,
        "item": 1
      }
    ],
    "status": "PACKED",
    "created_at": "2025-12-24T05:00:55.561269Z",
    "customer": 1,
    "agent": 1
  },
  {
    "id": 1,
    "items": [
      {
        "id": 1,
        "quantity": 2000,
        "packed_quantity": 0,
        "selected_color": "blue",
        "selected_size": "XL",
        "order": 1,
        "item": 1
      }
    ],
    "status": "PACKED",
    "created_at": "2025-12-24T05:00:55.561269Z",
    "customer": 1,
    "agent": 1
  }
  
]


