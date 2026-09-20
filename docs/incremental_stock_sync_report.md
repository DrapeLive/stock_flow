# Report: Incremental Stock Sync for the Mobile Inventory Screen

Status: **Complete — shipped and verified** (backend + mobile + device).

## 1. Summary

The Android admin app's Stock (Inventory) screen now loads its item list from a
local Hive store instead of re-fetching and re-parsing the full `stock-list`
payload on every visit. A new dedicated sync endpoint delivers the full catalog
once; afterwards only small deltas (changed items, stock rows, removed ids) are
transferred. The screen renders the snapshot instantly and refreshes in the
background, so open times no longer depend on network round trips or payload
size.

| | Before | After |
|---|---|---|
| Stock data TTC (cold) | ~1.6 s server fetch + parse | **9 ms** (store read) |
| Stock data TTC (warm) | ~190 ms | **4 ms** (store read) |
| Payload per screen visit | full `stock-list` (~1.4 MB) | full once, then KB-scale deltas |
| Offline | blank/error | shows last good snapshot + retry banner |

## 2. Design

- **One round trip per change, not per visit.** The first visit or a bootstrap
  performs a paged full sync; every later visit reads the Hive box synchronously
  (display) while a background trigger fetches the delta.
- **Single-flight + throttle.** `ItemSyncService` coalesces triggers: a 10 s
  minimum interval (bypassed by explicit `force`), one in-flight round at a time,
  and a 30 s overlap window (`since = cursor - 30s`) for idempotency.
- **Merging is local and cheap.** `ItemStore.commitDelta` upserts items whose
  `rev` (catalog `updated_at`) changed, applies flat stock rows on top, removes
  deleted ids, persists the new cursor last, then verifies a server-provided
  `check` (visible item count + total stock). A mismatch schedules a rate-limited
  (60 s) reconcile.
- **Self-healing.** If the delta degrades to a full page (too many changes,
  window exceeded) the service re-bootstraps. If the device clock disagrees on
  archival boundaries the checksum mismatch triggers reconcile.
- **Display-only store.** Every write path (create order, pack, dispatch, report)
  still hits the live server exactly as before. The store never answers writes.
- **Offline.** On network failure the service keeps the last good snapshot and
  surfaces `lastError`; the screen shows "Couldn't sync" with a Retry action.
- **Post-write refresh.** Any order or item mutation invalidates orders/items and
  fires a forced sync, so the Stock screen reflects the change on next visit.

## 3. Backend (Phase 2)

- Item/stock write sites now bump `catalog_updated_at` via `touch_catalog`
  (13 deduction/completion sites, restock, unpack, etc.). Item `created_at`
  gains `updated_at`; `Item` `rev = catalog_updated_at`.
- **New endpoint** `GET /api/items/sync/` (admin-only):

  - bare or `page`/`page_size` → **full** mode, paged (default 100, max 500);
    `next_page` drives client paging.
  - `since=<iso>` → **delta** mode: items changed since (`rev`), flat `stock``
    rows (esp. fast stock deductions), `removed_item_ids` (deleted or archived).
  - Both modes share the `active` queryset (archived items excluded via
    `out_of_stock_since__lte = cutoff`).
  - Response: `mode`, `cursor` (UTC ISO), `archive_after_days` (30), `items` [],
    `stock` [], `removed_item_ids` [], `check` {items, total_stock}, `next_page`.
  - Sane ceilings: delta >500 changes or `since` older than 14 days → `full`.
- All 13 stock write-sites bump the catalog timestamp (audited via tests).
- Migration `0010_item_catalog_updated_at_and_more`.

## 4. Mobile (Phase 3)

- `lib/data/item_store.dart` — pure merger logic (`ItemSyncData`) + box-backed
  `ItemStore` (Hive box `itemSync`, keys `i:<id>`, meta thead). Operations:
  bootstrap (clear → page → commit), delta (upsert/merge/remove →
  `commitDelta`). Exposes `entries()`, `check()`, `hasBootstrapped`, `cursor`,
  `archiveAfterDays`.
- `lib/features/items/item_sync_service.dart` — `WidgetsBindingObserver` +
  `revision` / `lastSynced` / `syncing` / `lastError` `ValueNotifier`s;
  `trigger({force})`, `_bootstrap`, `_delta`, `_scheduleReconcile`, overlap
  window, force-pending replay.
- `lib/features/items/items_screen.dart` — `initState` attaches to the service,
  `_load()` reads the store synchronously (instant TTC), kicks the background
  trigger, keeps live `unpacked` + `sizeRanges` fetch; `_refresh()` (pull-
  to-refresh/Retry) forces a sync; local sync-progress bar + error banner;
  reconciles `OrderRepo`/`ItemRepo` invalidation and logout clear.
- `AppCache` opens `itemSync` box and adds `clearItemSync()`.

## 5. Test results

- Backend: **114 tests OK** (70.5 s) including new `ItemSyncAPITests`
  (full paging, delta content, removal, active-query, auth
  enforcement). Items suite alone: 50 tests.
- Mobile: `flutter analyze` clean (0 errors/0 warnings, 10 pre-existing info
  items) and **172/172 tests pass**, including `item_store_test.dart`
  (merger unit tests) and `item_sync_service_test.dart` (real-async
  bootstrap+verify round). All Stock-screen widget tests were migrated from a
  plain `stock-list` mock to seeded-store + sync mock fixtures.
- **Bug found & fixed during test bring-up:** `http_mock_adapter` resolves to
  the *last* registered matching mock, so a query-less full-page stub shadowed
  the `since` delta stub and made bootstrap→verify recurse indefinitely. Test
  fixture registers the specific `since` mock after the generic one.

## 6. Device verification (Phase 4)

Emulator `Pixel_8_API_34`, live backend (`10.0.2.2:8000`, seeded data), via
`integration_test/measure_test.dart`:

```
[MEASURE] tab :: STOCK cold  = 1037ms      items::TTC = 9ms
[MEASURE] tab :: STOCK warm  =  730ms      items::TTC = 4ms (1ms on cache-hit reruns)
[MEASURE] tab :: ORDERS cold = 1516ms
[MEASURE] tab :: USERS cold  = 1496ms
[MEASURE] tab :: STATS cold  = 1300ms / warm 1230ms
[MEASURE] rapid :: walk=3865ms {USERS:659, STOCK:723, STATS:908, ORDERS:884}
```

On-device sync observed: bootstrap full page `3805B` (337 ms) → verify delta
`183B` (797 ms). The Stock tab's remaining cost is framework/animation work,
not data.

## 7. Contract notes & accepted deviations

1. **Additive variant fields (deviation from written contract, deliberate):**
   the sync `items[].variants[]` payload additionally emits `qr_code`,
   `display_order`, and `image` (absolute URI or null). Without these the Stock
   screen would lose variant thumbnails, colour labels, and per-variant QR print
   — a visible regression. Adding keys is backward compatible; all pre-existing
   endpoints and payload shapes are unchanged.
2. Local `check` mirrors the server `active` rule using the device-local
   `archiveAfterDays`. Boundary cases (item archived near the same second on the
   server) self-heal via the 60 s reconcile.
3. `since` requests are answered as `delta` even with a fresh cursor; the client
   merges idempotently, so deltas are safe to replay after any failure.
4. Hive box is local device state; logging out clears it (a fresh account does
   its own bootstrap).

## 8. Files (feature diff)

Backend:
- `apps/items/views.py` — `/api/items/sync/` + `_sync_items_payload`
- `apps/items/models.py` — `updated_at`, `touch_catalog`, archive queryset helper
- `apps/items/services.py` — timestamp/archive helpers (new)
- `apps/items/signals.py`, `apps/items/tasks.py` — restock/unpack/archive touch_catalog
- `apps/items/serializers.py` — variant sync fields
- `apps/orders/*`, `apps/agents/*`, `apps/customers/*`, `apps/dashboard/*` —
  stock write-sites bumping `catalog_updated_at`
- `apps/items/tests.py` — `ItemSyncAPITests`; `apps/items/migrations/0010_*`
- `config/urls.py`, `config/settings.py` — route/config wiring
- `apps/items/management/commands/purge_archived_items.py` (new, archival/maintenance)

Mobile:
- `lib/data/item_store.dart` (new), `lib/features/items/item_sync_service.dart` (new)
- `lib/features/items/items_screen.dart`, `lib/core/cache/app_cache.dart`
- `lib/data/repositories.dart` (post-write triggers), `lib/providers.dart` (logout clear)
- `test/item_store_test.dart`, `test/item_sync_service_test.dart` (new),
  `test/helpers.dart` (+ fixtures), `test/items_image_preview_test.dart`,
  `test/ordered_items_test.dart`, `test/widgets_smoke_test.dart`

## 9. Verification commands

```bash
cd backend && venv/Scripts/python.exe manage.py test            # 114 OK
cd mobile && flutter analyze                                    # clean
cd mobile && flutter test                                       # 172 OK
cd backend && venv/Scripts/python.exe manage.py runserver 0.0.0.0:8000
cd mobile && flutter test integration_test/measure_test.dart -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=MEDIA_DOMAIN=http://10.0.2.2:8000
```

## 10. Follow-ups (optional, not blocking)

- Pre-cache variant images to Hive on bootstrap so thumbnails render fully
  offline (currently network-backed with placeholder fallback).
- Consider relying on the local store for the QR-print screen (currently still
  live `stock-list`).