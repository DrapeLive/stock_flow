# Fix Agent Customer Detail Page

## Problem
The agent customer detail page was copied from the admin version and contains:
- Admin-specific routes
- Edit/delete functionality that agents shouldn't have

## Changes Required

### File: `frontend/app/(agent)/agent/customers/[id]/page.tsx`

#### 1. Remove unnecessary imports (lines 6, 8-9, 12-16)
Remove:
- `agentApi` import
- `toastSuccess, toastError` imports
- `CustomerUpdateRequest` from customer types import
- `Input`, `Textarea` imports
- `StockFlowButton`, `StockFlowSelect` imports
- `Trash2`, `Pencil`, `Eye` from lucide-react

#### 2. Simplify state (lines 28-39)
Remove:
- `agents` state
- `formData` state
- `saving` state
- `errors` state
- `isEditing` state

Keep only: `customer`, `orders`, `loading`

#### 3. Simplify fetchData (lines 41-74)
Remove:
- `agentsData` fetch and mapping

#### 4. Remove functions (lines 76-124)
Remove entirely:
- `handleChange`
- `validate`
- `handleUpdate`
- `handleDelete`

#### 5. Simplify UI (lines 135-374)
Remove:
- Edit/delete buttons from header (lines 153-171)
- Entire edit mode form section (lines 194-270)
- Avatar backgroundColor conditional (line 179-181)
- User icon color conditional (line 186)

Fix:
- Line 323: Change `/admin/order/status/${order.id}` to `/agent/order/status/${order.id}`

Keep:
- View mode customer details section
- Order history section with corrected routes
