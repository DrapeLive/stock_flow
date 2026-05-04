# Add Pagination to Customer Order History

## Context
Both admin and agent customer detail pages display order history without pagination. The backend already supports pagination on `/api/orders/` endpoint with:
- Default page size: 50
- Configurable via `page_size` query param
- Max page size: 200

## Changes Required

### 1. Update `frontend/lib/api/order.ts`
**Purpose**: Add pagination support to `getByCustomer` method

**Changes**:
- Modify `getByCustomer` signature to accept optional pagination params
- Update return type to `Promise<PaginatedResponse<OrderAllResponse[number]>>`
- Add `page` and `page_size` to query string

```typescript
getByCustomer(
  customerId: number, 
  params?: { page?: number; page_size?: number }
): Promise<PaginatedResponse<OrderAllResponse[number]>> {
  const query = new URLSearchParams();
  query.append("customer", customerId.toString());
  if (params?.page) query.append("page", params.page.toString());
  if (params?.page_size) query.append("page_size", params.page_size.toString());
  return api
    .get<PaginatedResponse<OrderAllResponse[number]>>(`/api/orders/?${query.toString()}`)
    .then((r) => r.data);
},
```

### 2. Update `frontend/app/(admin)/admin/users/customers/[id]/page.tsx`

**Add imports**:
- `Pagination` from `@/components/ui/Pagination`

**Add state**:
```typescript
const [currentPage, setCurrentPage] = useState(1);
const [pageSize] = useState(50);
const [totalOrders, setTotalOrders] = useState(0);
const [totalPages, setTotalPages] = useState(0);
```

**Update useEffect** (lines 41-74):
- Call `orderApi.getByCustomer(numericId, { page: currentPage, page_size: pageSize })`
- Update state with paginated response:
  - `setOrders(filteredOrders)` (from `results` array)
  - `setTotalOrders(response.count)`
  - `setTotalPages(Math.ceil(response.count / pageSize))`
- Add `currentPage` to dependency array

**Add pagination handler**:
```typescript
const handlePageChange = (page: number) => {
  setCurrentPage(page);
  window.scrollTo({ top: 0, behavior: "smooth" });
};

const handlePageSizeChange = (size: number) => {
  setCurrentPage(1);
};
```

**Add Pagination component** (after order history section, before closing div):
```tsx
{orders.length > 0 && (
  <Pagination
    currentPage={currentPage}
    totalPages={totalPages}
    totalCount={totalOrders}
    pageSize={pageSize}
    onPageChange={handlePageChange}
    onPageSizeChange={handlePageSizeChange}
  />
)}
```

### 3. Update `frontend/app/(agent)/agent/customers/[id]/page.tsx`

**Apply identical changes as admin page**:
- Add `Pagination` import
- Add pagination state variables
- Update `useEffect` to call paginated API
- Add page change handlers
- Add `Pagination` component after order history

## Files Modified
1. `frontend/lib/api/order.ts` - Update `getByCustomer` method
2. `frontend/app/(admin)/admin/users/customers/[id]/page.tsx` - Add pagination UI and logic
3. `frontend/app/(agent)/agent/customers/[id]/page.tsx` - Add pagination UI and logic

## Testing Notes
- Verify pagination renders correctly when orders > 50
- Verify page navigation fetches correct data
- Verify page resets to 1 when needed
- Confirm both admin and agent pages work identically
