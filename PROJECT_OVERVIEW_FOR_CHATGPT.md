# Stock Flow — Complete Project Overview for AI-Assisted Development

> **Purpose of this document:** Give another AI (e.g. ChatGPT) enough context to understand, debug, and plan work on this project without asking the human to re-explain it. It describes **what exists in the code today**, not what an ideal design would be. Statements are sourced from actual code; file references are listed inline. Where something could not be confirmed, it is explicitly marked "Not confirmed from the current codebase".

> **A note on naming:** The repo contains **three applications sharing one Django backend**:
> 1. `frontend/` — the **web app** (Next.js 16 / React 19). Covers BOTH admin and agent experiences. ("Admin / Agent" UI.)
> 2. `mobile/` — a **Flutter Android app** (`stock_flow_admin`). **Admin-only** companion app that mirrors part of the web admin.
> 3. `backend/` — the **Django REST API** that both consume.
>
> Throughout this doc, "frontend" means the Next.js web app, "mobile app" means the Flutter app, and "backend/API" means Django.

---

## 3. Project Summary

### Simple-language explanation

**Stock Flow** is a B2B wholesale garment/order-management platform for an apparel business ("XL Apparals"). A warehouse admin maintains a catalogue of clothing items (each item has colour "variants", each variant has size ranges and stock). Field sales **agents** scan a garment's QR code, pick a customer, and build an order. Placing an order **deducts stock**. The warehouse then packs and dispatches orders. Every stage (Draft → Pending → Packed → Dispatched) is tracked, a deduction/restock safety system prevents negative stock, and everything is audited in order logs. Admins manage items, users (admins/agents/customers), brands, transports, and see analytics.

### Technical facts (verified)

| Aspect | Value |
|---|---|
| Project name | Stock Flow (`stock_flow_backend` / `stock_flow_admin`) |
| Business domain | B2B apparel/garments wholesale — order, inventory and dispatch management |
| Backend | Django **5.2.14**, Python **3.12**, Django REST Framework 3.16.1, SimpleJWT 5.5.1 |
| Web frontend | Next.js **16.2.2**, React **19.2.3**, TypeScript, Tailwind v4, shadcn/ui, pnpm 11.9, Node >=24 <25 |
| Mobile app | Flutter / Dart (SDK `^3.5.0`), Riverpod 2, go_router, Dio, Hive CE, CachedNetworkImage |
| Database | PostgreSQL (production via docker `postgres:16-alpine`; configured in `config/settings.py`) |
| Cache / broker | Redis 7 (`redis:7-alpine` in compose) — used as Celery broker/result backend |
| Background workers | Celery worker + Celery beat (scheduled cleanup task) |
| Realtime | **None via WebSockets.** Web push (VAPID / pywebpush) for notifications only. |
| Auth | JWT (SimpleJWT). Access token lifetime = **30 days**. Custom forgot/reset-password flow. |
| File storage | Local filesystem (`MEDIA_ROOT`), image transforms via Pillow; served under `/media/`. |
| Hosting/deployment | Backend: Docker Compose (Django/Gunicorn/Postgres/Redis/Celery). Web frontend: **Vercel** (`stockflow-sigma.vercel.app`, from `.env.example` default CORS). Mobile: Android APK. |
| External services | SMTP email (password reset), Web Push (VAPID keys), MobileScanner camera QR, printing. |
| Current status | Actively developed; both web and mobile admin apps mirror the same backend; see "Current Project Status". |

**Frontend/backend communication:** Both clients call the Django REST API over HTTPS/HTTP JSON with `Authorization: Bearer <JWT>`. There is no GraphQL, no WebSocket channel, no SSR-to-BFF for data.

---

## 4. Business / Product Overview

### Main users and workflows (as implemented)

**User flow — Admin (warehouse)**
1. Logs in on web (`/`) or the Flutter app. Only accounts with `role=ADMIN` can use the mobile app (mobile enforces this client-side).
2. Creates/maintains **Items** (name, description, price, type `kids|gents`, brand). An item has **variants** = colours (each with a unique **QR code** and a photo), each variant has **size rows** with stock.
3. Assigns **items** (specific variants) to agents so agents can add them to orders.
4. Creates/manages **agents** and **customers**; assigns customer to agent; transport preferences; bulk-import customers from an Excel/CSV file.
5. Watches the **Orders** dashboard (All/Pending/Packed/Dispatched tabs), filters, searches.
6. On an **order status page** the admin can: see items, **pack** quantities, **dispatch** (set transport company + LR number), edit quantities, delete items/orders (PIN-gated), view activity logs, and generate the invoice (JSON data; printable PDF on the web app).
7. Views **Analytics** (KPIs, daily trend, top customers/agents/items, dispatch-time metrics) and **Summary** (stock totals).
8. Prints **QR labels** (58×90 mm) for variants; scans QR codes to look up items.

**Agent workflow**
1. Logs in on web at `/` (agent role).
2. Dashboard lists their performance/orders, customers.
3. Scans an **item QR code** (dedicated scanner) or browses their **assigned items**.
4. Creates an **order**: picks a customer (or creates one), scans/selects items, selects size-group + quantity, submits. During creation the UI shows live availability (`by-qr/out-of-stock`).
5. Submit → order becomes **PENDING**, stock is deducted. Receives push notifications for dispatch and stock errors.
6. Can **edit** a PENDING order (reservation-snapshot edit flow) and see order status/history. Invoice PDF can be downloaded/shared (web).

**Customer workflow** — mostly passive: customers are records (name/address/contact/GST/agent) attached to agents. The platform stores order history and dispatch/transport info per customer.

### Order lifecycle (exact, from backend code)

```
DRAFT  →  PENDING  →  PACKED  →  DISPATCHED
              ↘  EDITING (sub-state used during editing; reverts to PENDING)
```

- **DRAFT** order is created first (agent adds items without touching stock). See `AddOrderItemView` (`backend/apps/orders/views.py:743`) and `PlaceOrderView` (`backend/apps/orders/views.py:81`).
- **PENDING** = order placed; stock deducted once; admin can now pack/dispatch.
- **EDITING** = an in-progress edit of a PENDING order. `StartEditView` snapshots items into `reservation_snapshot` and records `editing_started_at`; `SaveEditView` returns the old stock, re-checks + re-deducts, and clears the snapshot; `cancel_edit` restores the snapshot. NOTE: `StartEditView` does **not** itself set `status=EDITING`; status handling relies on a separate PATCH by the caller. `OrderViewSet.get_queryset` reverts EDITING orders older than 15 minutes and deletes DRAFT orders older than 15 minutes.
- **PACKED** = partially/fully packed at the warehouse (per-item `packed_quantity`).
- **DISPATCHED** = `dispatch_order` sets `dispatched_at`, transport company + LR number; **unpacked** quantities are returned to stock. Older than 30 days → moves to "archived".
- **Invoice**: `InvoiceView` returns **JSON** (`InvoiceSerializer`) including `total_price` = Σ(price × quantity × pieces), `gst_rate` (from settings). The **backend does not generate PDFs**; the web app renders an invoice PDF client-side (react-pdf).

### Inventory workflow (exact)
- Stock lives on `ItemVariantSize.stock` (one row per variant × size). **Stock is derived as the sum across a variant's sizes.**
- Stock changes ONLY at: order placement (deduct), order edit save (return+re-deduct), order/item deletion of a non-DRAFT order (return), dispatch of unpacked (return). Adding an item to a DRAFT/EDITING order never changes stock.
- A variant/item is "out of stock" when summed stock == 0 → `out_of_stock_since` is stamped (`apps/items/signals.py`). Items out of stock for >30 days vanish from normal lists (only in `archived`).
- All availability endpoints add an **edit boost** (`get_agent_reservation_boost`): while an agent has an EDITING order, the reserved quantities are shown as available again.

### Main modules
Admin: Items/Variants/Stock, Orders, Users (Admins/Agents/Customers), Analytics, Summary, Bulk Import, Profile. Agent: Dashboard, Items/scanner, Customers, Order creation/edit/history, Profile. Business: Brands, Transports, Settings (web admin).

---

## 5. User Roles and Permissions

Roles are enforced at TWO layers: backend (DRF permission classes and queryset scoping) and frontend/mobile (UI hiding). **Frontend hiding is NOT a security boundary** — the backend is the authority.

### ADMIN

- **Backend identity:** `User.role == "ADMIN"`; optionally `business` ∈ {gents, kids}; optionally linked to a `Brand`.
- **Endpoint access:**
  - Reads: all authenticated endpoints (orders, items, customers, agents, dashboard, analytics, invoice, logs, transports, brands).
  - Writes: item/variant create/update (writes need `IsAdmin`); admin-user create (`AdminViewSet`, `IsAdmin`); agent/customer create/update; order dispatch, update, delete-item, mark-viewed, etc. (`IsAuthenticated`).
  - **Protected writes that require the admin's PIN:** deleting an order, item, customer, agent, or brand. `check_admin_pin(request)` (`backend/apps/accounts/permissions.py:38`): superuser or AGENT → pass; other non-ADMIN role → 403; ADMIN without/invalid `pin` in request body → 403.
- **Scoping:** a NON-superuser admin with `business` set is restricted to that business type in:
  - Orders list (`backend/apps/orders/views.py:447` — admin_business filter on order items), invoices, order logs, order-item update, `order-ids`, `archived`
  - Items: `items/views.py` `filter_items_by_business`
  - Dashboard + analytics (`apps/dashboard/views.py`)
  - Customer "has business orders", agent items (business-scoped), customer-requirements
- **What it sees:** all orders (within business scope), all customers (within business), all agents, all items.
- **What it cannot do:** superuser-only actions are Brands **write** (`IsSuperuser`), brand assignment of a new admin without their own brand, cross-business viewing.

### AGENT

- **Backend identity:** `User.role == "AGENT"` with a linked `Agent` (OneToOne).
- **Endpoint access:**
  - `AddOrderItemView` and `StartEditView`, `SaveEditView` are `IsAgent` (role == AGENT).
  - Everything else the agent uses is `IsAuthenticated` but **queryset-scoped to their own data**:
    - Orders: `Order.objects.filter(agent__user=request.user)` (`OrderViewSet.get_queryset`).
    - Customers: only customers whose `agent` is theirs (`CustomerViewSet.get_queryset`).
    - Agent record: `IsAdminOrSelfAgent` — agent can only touch their own Agent object.
  - Ownership checks (`order.agent.user != request.user` → 403) on save-edit, cancel-edit, order logs.
- **Item access:** agents can only add **assigned** items to orders (`AgentItem` join table check in `AddOrderItemView`). The web agent's item/scanner list is driven by their assigned variants.
- **Restrictions:** no access to dashboard/analytics (both `IsAdmin` only), no admin-user management, no brands write, no transport writes, cannot delete orders/items/customers/agents (PIN path is for ADMIN deletes; agents pass PIN check but have no `destroy` route exposed to them in the UI and their `Agent` destroy is via `IsAdminOrSelfAgent` object check).
- Agents placed orders trigger stock deduction; admins matching the item's brand+business get push notifications.

### SUPERUSER (implied role)

- `is_superuser=True` forces `role="ADMIN"` (`accounts/models.py:35`).
- Can create user accounts across business types and assign brands; does NOT need a PIN for destructive ops; only role that can write **Brands**; can create other admins with any business.
- There is no dedicated superuser screen in the mobile app (omitted); web has `/admin/settings` (brands, transports) and `/admin/users/admins/*`.

### PERMISSIONS SUMMARY (backend classes)

| Class | Rule | File |
|---|---|---|
| `IsAgent` | authenticated AND role == "AGENT" | `apps/accounts/permissions.py:5` |
| `IsAdmin` | authenticated AND role == "ADMIN" | `apps/accounts/permissions.py:10` |
| `IsSuperuser` | authenticated AND is_superuser | `apps/accounts/permissions.py:17` |
| `IsAdminOrSelfAgent` | authenticated; object-level: ADMIN ok, else `obj.user == request.user` | `apps/accounts/permissions.py:22` |
| `IsAdminUser` (DRF built-in) | `request.user.is_staff` (used for transport writes) | `transports/views.py` |
| `check_admin_pin(request)` | helper used by many destroy views | `apps/accounts/permissions.py:38` |

**Frontend restrictions (client-side only, not backend):**
- Mobile app refuses login when `role != "ADMIN"` (`AuthRepo.login` throws "Only admin accounts can use this app.").
- Mobile bottom nav has no Settings/Admins tabs ("superuser-only" per `mobile/SETUP.md`).
- Web `proxy.ts` (Next 16 middleware) blocks `/admin/*` for non-ADMIN role and redirects to `/agent`; expires/clears stale JWT cookies.

---

## 6. Frontend (Mobile — Flutter) Overview

### Versions & dependencies
`mobile/pubspec.yaml`: Dart SDK `^3.5.0`. Core: `flutter_riverpod ^2.6.1`, `go_router ^14.8.1`, `dio ^5.7.0`, `hive_ce ^2.8.3` + `hive_ce_flutter ^2.2.0`, `path_provider`, `connectivity_plus ^6.1.0`, `cached_network_image ^3.4.1`, `image_picker ^1.1.2`, `image ^4.3.0`, `file_picker ^8.1.2`, `mobile_scanner ^5.2.3`, `qr_flutter ^4.1.0`, `pdf ^3.11.1`, `printing ^5.13.4`, `share_plus`, `open_filex`, `excel ^4.0.6`, `fl_chart ^0.69.0` (installed but unused), `intl`, `google_fonts`, `permission_handler`, `url_launcher`. Dev: `flutter_lints ^5.0.0`, `http_mock_adapter ^0.6.1`. **No `flutter_secure_storage`, no `shared_preferences`.**

### Entry point & initialization — `mobile/lib/main.dart`
- `AppCache.init()` (opens Hive boxes in app-documents dir).
- `ApiClient.init()` (builds Dio + auth interceptor).
- A single hoisted `ProviderContainer` + `UncontrolledProviderScope` so the static 401 hook can reach the session notifier.
- `onUnauthorized = () => container.read(sessionProvider.notifier).logout()` — any HTTP 401 logs the user out.
- `StockFlowApp` (`mobile/lib/app.dart`) → `MaterialApp.router(title: 'Stock Flow Admin', theme: AppTheme.light(), routerConfig: ref.watch(routerProvider))`.

### State management — Riverpod (CodeGen-free)
- `mobile/lib/providers.dart`:
  - `sessionProvider` — `NotifierProvider<SessionController, Session?>`: login, logout, `persistSession()`, restores session from Hive on start, forwards token to Dio.
  - `connectivityProvider` — `StreamProvider<bool>` from `connectivity_plus` driving an offline banner.
- **Screens do NOT use providers for data.** Each screen runs manual `_load()` async methods with local `_loading`/`_error` booleans + `setState`. Loading/error/empty states use shared `PageLoading`, `EmptyState`, and `RefreshIndicator`.
- Caching is done in the repository layer via `AppCache` (not in widgets/state).

### Routing & navigation — `mobile/lib/core/router/app_router.dart`
- `routerProvider = Provider<GoRouter>` on `refreshListenable` (a `ValueNotifier` bumped on session changes).
- Redirect: unauthenticated → `/login`; authenticated from `/login` or `/` → `/admin`. No other guards (a single redirect function).
- Flat `GoRoute` list (no ShellRoute — bottom nav is a custom widget, see AdminNavBar):

| Path | Screen |
|---|---|
| `/login` | `LoginScreen` |
| `/forgot-password` | `ForgotScreen` |
| `/reset-password/:token` | `ResetScreen` |
| `/admin` | `DashboardScreen` (Orders) |
| `/admin/profile` | `ProfileScreen` |
| `/admin/analytics` | `AnalyticsScreen` |
| `/admin/summary` | `SummaryScreen` |
| `/admin/bulk-import` | `BulkImportScreen` |
| `/admin/users` | `UsersScreen` |
| `/admin/users/customers/new` | `CustomerNewScreen` |
| `/admin/users/customers/:id` | `CustomerDetailScreen` |
| `/admin/users/agents/new` | `AgentNewScreen` |
| `/admin/users/agents/:id` | `AgentDetailScreen` |
| `/admin/items` | `ItemsScreen` (Inventory) |
| `/admin/items/new` | `ItemWizardScreen` |
| `/admin/items/edit/:id` | `ItemEditScreen` |
| `/admin/items/ordered/:id` | `OrderedItemsScreen` |
| `/admin/items/qr/:qr` | `QrLabelScreen` |
| `/admin/items/qr-print` (`?item=`) | `QrPrintSelectScreen` |
| `/admin/order/status/:id` | `OrderStatusScreen` |
| `/admin/order/status/:id/edit` | `OrderEditStubScreen` (lightweight stub) |

- Navigation idioms: `context.push()` for detail screens; `context.go()` for root swaps; back-button fallback pattern used everywhere: `context.canPop() ? context.pop() : context.go('/admin')`. Android back pops routes naturally; the GoRouter redirect handles post-login/logout.
- The `AdminNavBar` (`mobile/lib/shared/admin_shell.dart`) has 4 tabs: Users (`/admin/users`), Orders (`/admin`), Stats (`/admin/analytics`), Stock (`/admin/items`).

### API layer — `mobile/lib/core/api/api_client.dart`
- `ApiClient` (static) wraps **Dio**; `BaseOptions(baseUrl: AppConfig.baseUrl, connectTimeout 15s, receiveTimeout 45s)`.
- Interceptor adds `Authorization: Bearer <token>`; on 401 → `onUnauthorized()` (→ logout).
- `mapError()` → `ApiException(message, statusCode, isNetwork)`; message extraction prefers `error_message`, `message`, `detail`, `error`, then field-specific, `pin` → 'Incorrect PIN'.
- **No refresh-token flow** — access tokens last 30 days in backend config; 401 means re-login.

### Local storage / caching — `mobile/lib/core/cache/app_cache.dart`
Three **Hive CE** boxes: `session` (auth), `prefs` (UI state e.g. active tabs, unread-only toggle), `cache` (namespaced TTL JSON). Strategies: `networkFirst(namespace, key, fetch)` always fetches, falls back to cache on error; `staleWhileRevalidate(namespace, key, fetch, ttl)` serves fresh cache under TTL. TTL examples: sizeRanges 7 days, transports 24h, agents 30min, analytics 15min, viewed-ids 5min, all-ids 2min, variants 15min. Writes invalidate namespaces (`orders/order/unpacked/dash`, `items/item/summary`, `customers/customer`, `agents/agent`).

### Theme — `mobile/lib/core/theme/app_theme.dart`
`AppColors` constants mirror web `globals.css` (primary `#FF6200`, pending red, dispatched green, borders `#D9D9D9`, muted `#919191`, status badge palettes). `AppTheme.light()`: Material 3, `ColorScheme.fromSeed(seed: primary)`, Google Fonts Plus Jakarta Sans, custom AppBar/Card/Input/ElevatedButton/TextButton/Divider/Dialog/SnackBar themes, radius 10–14, `InkSparkle` splash. **Light theme only.**

### Images — `mobile/lib/shared/widgets.dart`
- `AppImage` uses `CachedNetworkImage` with `AppConfig.resolveImageUrl(path)` (absolute http(s) passthrough; else `https://$MEDIA_DOMAIN` if set, else `$baseUrl`). Default cache manager (memory + disk).
- `showImagePreview(context, path)` full-screen preview dialog reusing the same resolved URL (cached bytes).

### Android specifics
- `mobile/android/app/build.gradle.kts`: applicationId `com.xlapparals.stock_flow_admin`, Kotlin 2.1.0, AGP **8.7.3**, compile/min/target from Flutter defaults, **release signed with debug key** (TODO in file). `usesCleartextTraffic="true"` (dev HTTP). Manifest permissions: INTERNET, CAMERA.
- Known local issue: this Flutter SDK requires AGP ≥ 8.11.1 (the app builds with `flutter build apk --android-skip-build-dependency-validation`).

### Error/loading/offline behavior
- Screen-level `_loading`/`_error` + `PageLoading`/`EmptyState`/retry buttons; `RefreshIndicator` pull-to-refresh on list screens; `OfflineBanner` ("Offline — showing cached data") driven by connectivity; repository `networkFirst`/`staleWhileRevalidate` returns cached data offline; offline writes are not queued (they fail with `ApiException(isNetwork: true)`).

---

## 7. Mobile App Screen Inventory

Each screen mirrors a web route (every screen file has a `/// Mirrors …` comment).

### `LoginScreen` — `mobile/lib/features/auth/login_screen.dart`
- Purpose: admin sign-in. UI: `AuthBranching`/`AuthCard`, email + password fields (password eye toggle), forgot-password link, error/warn `AuthAlert`, shake-on-invalid animation.
- Actions: `login` via `sessionProvider.notifier.login(email, password)`; forgot → `/forgot-password` (push).
- Business logic: client-side validation; error classification (`No internet connection`, `Wrong password`, `No account found`, "Admin access only" warning); `AuthRepo.login` rejects `role != 'ADMIN'`.
- Post-login: GoRouter redirect to `/admin`.

### `ForgotScreen` — `auth/forgot_screen.dart`
- Sends `repos.auth.forgotPassword(email)` (lowercase), on success → `/login`.

### `ResetScreen(token)` — `auth/reset_screen.dart`
- Password + confirm with min-8 and match validation; `repos.auth.resetPassword(token, password)`; → `/login`.

### `AuthCard` / `AuthAlert` / `PasswordField` / `AuthSubmitButton` / `AuthBranding` — `auth/widgets.dart`
- Reusable login/forgot/reset visual kit (orange-branded card 24px radius, alert banners, password field with visibility, primary submit button).

### `DashboardScreen` — `mobile/lib/features/dashboard/dashboard_screen.dart`
- Purpose: Orders feed / admin home. `AdminScaffold(title: 'Orders')`.
- Tabs: All / Pending / Packed / Dispatched (`_tabBar`, active state = orange pill, inactive gray) persisted in `prefs['adminOrdersActiveTab']`.
- Header: unread count (amber), filter chip (from/to date, agent dropdown, customer bottom-sheet picker) + debounced search (300ms), "Unread Only" toggle (persisted `adminUsersUnreadOnly`).
- Data: `allIds` (2min SWR) + `getViewedIds` (5min SWR) → counts + unread marks; page load `order.getAll(OrderFilters(...))` (page size 50) with per-tab pagination.
- Card `_OrderCardView`: customer avatar+name, agent username, id, date, `StatusBadge`, unfolded-count pill, Sets + pieces, `formatInrInt` value; unviewed rows tinted + green dot; tap → `markViewed` + push `/admin/order/status/:id`.
- Re-fetches when connectivity goes online (`ref.listenManual` on `connectivityProvider`).

### `OrderStatusScreen(orderId)` — `mobile/lib/features/orders/order_status_screen.dart`
- Full order management: tabs Packing | Dispatching (auto-jump to Dispatching when status is PACKED); delete shortcut when `_isDeletable` (PENDING/PACKED); order summary card (customer/agent/date/status/expected delivery/transport/notes/dispatch info with LR copy-on-tap); per-item rows with green pack checkbox, edit pencil, delete trash.
- Business logic: `_togglePacked` toggles `packed_quantity` 0↔total; editing an item opens `_OrderItemEditSheet` computing available stock (size-bucket stock minus other items) with "Only N sets available" guard; "Update Packing"/"Done Selecting" flow; dispatch dialog (transport dropdown + LR + note about unpacked goods) → `order.dispatch`; delete → `PinDialog` → `order.delete(id, pin)`; logs expandable (`OrderLog` actions with styles); after dispatch/delete → `go('/admin')`.
- APIs: `order.getOne`, `transport.active`, `order.getLogs`, `order.updateItem`, `order.update`, `order.dispatch`, `order.deleteItem`, `order.delete`, `item.allVariants` + `item.sizeRanges` for the edit sheet.

### `OrderEditStubScreen(orderId)` — `orders/order_edit_stub_screen.dart`
- Lightweight parity screen: lists items, 'Save' calls `order.update`, then `go` back to status. Row edits happen on the status screen.

### `ItemsScreen` — `mobile/lib/features/items/items_screen.dart`
- Inventory (Stock tab). `AdminScaffold(title: 'Inventory')`: Total Items pill, Add button; search + QR scanner button (`_QrScanSheet` with `MobileScanner`, single-shot); active-filter banner; segmented tabs In-Stock / Out-of-Stock / Ordered with counts.
- `_ItemCardView`: `AppImage` thumbnail (tap → `showImagePreview`), name, type badge, variants count, edit ✎ / print-QR actions, expand → `_VariantCardView` (variant image, `Color #N`, truncated QR, horizontal `_SizeStockChip` list `range / N Sets / pcs-per-set`, out-of-stock tint, per-variant print icon); `_OrderedGroupCard` groups unpacked order items.
- Data (parallel): `item.stockList()`, `order.unpacked()`, `item.sizeRanges()`; stock-availability via `stock_validators.dart`; "Show more" 40-item paging.
- Actions: Add → `/admin/items/new`; Edit → `/admin/items/edit/:id`; Print-all → `/admin/items/qr-print?item=:id`; Print-one → `/admin/items/qr/:qr`; Ordered group → `/admin/items/ordered/:id`.

### `ItemWizardScreen` — `items/item_wizard_screen.dart`
- 3-step create wizard: Step 1 common fields (name/description/price, type kids/gents pre-filled from user.business), Step 2 colour-variant list (add/edit/delete draft variants), Step 3 per-variant size stock (`VariantForm`).
- Save → `item.createMultipart(...)` (multipart FormData: `variants[i]image`, `variants[i]display_order`, `variants[i]sizes[j]size|stock`). Size options from `item.sizeRanges()` (item_creation vs order_creation distinction).

### `VariantForm` (ColorVariantDraft, flattenVariantSizes) — `items/variant_form.dart`
- Size-range dropdown, per-bucket stock, gallery image pick (`ImagePicker`). Expands kids ranges via `kSizeRangeToSizes`.

### `ItemEditScreen(itemId)` — `items/item_edit_screen.dart`
- Edit item: common fields + `_VariantGroup` list (expandable; `backendId` negative = unsaved; `newImagePath` from gallery). Save → `item.update` then queued `patchVariantImage` for new images; Delete (PIN) → `item.deleteWithPin`.

### `OrderedItemsScreen(itemId)` — `items/ordered_items_screen.dart`
- Per-item customer requirements: groups unpacked OrderItems by customer (name, `Color #N`, quantity, size group, variant image) via `item.customerRequirements(itemId)`.

### `QrLabelScreen(qr)` — `items/qr_label_screen.dart`
- Single QR label auto-print on open (`byqrcode` → `buildQrLabelsPdf` → `Printing.layoutPdf`).
### `QrPrintSelectScreen({itemId})` — `items/qr_print_select_screen.dart`
- Multi-select variants to print labels; per-item filter via `?item=`; uses `stockList()`/`getOne`.
### `qr_label_pdf.dart`
- `buildQrLabelsPdf(...)`; label page `PdfPageFormat(58*2.83, 90*2.83)` (58×90 mm); QR via `QrPainter` (qr_flutter).

### `UsersScreen` — `mobile/lib/features/users/users_screen.dart`
- Customers/Agents segmented tab hub (persisted `prefs['adminUsersActiveTab']`), Add buttons, debounced search (400ms), list tiles (customer: name/address/agent badge; agent: displayName/email/+91/CLIENTS count), Show-More pagination, `RefreshIndicator`. Admins tab deliberately omitted (superuser-only).

### `CustomerDetailScreen(customerId)` — `users/customer_detail_screen.dart`
- Customer profile: info card (Edit/Save/Cancel toggle, name/address/contact/GST with regex validation, GST uppercased), agent chip + dropdown, orders section (paginated, DRAFT excluded, tap → order status), delete via `DeleteWithTransferDialog` (customer: always deactivate) → `customer.delete(id, pin, action: ...)`.

### `CustomerNewScreen` — `users/customer_new_screen.dart`
- Create customer form (name/address/contact/GST), agent dropdown (`agent.list`), transport preloaded (`transport.active`), regex validations, save → `customer.create`.

### `AgentDetailScreen(agentId)` — `users/agent_detail_screen.dart`
- Agent profile + item assignment: profile card with edit form (display name, contact, derived username with uniqueness via `derive_username`), assignable variant list from `item.allVariants()` (current vs changed sets), QR scan sheet (`MobileScanner`) to add variants, actions: Transfer Items / Copy Items to another agent, Clear all items, Delete (transfer-or-deactivate + PIN). Save items → `agent.updateItems(agentId, variantIds)`; transfer/copy → `agent.transferItems`/`copyItems`. (PDF download omitted vs web.)

### `AgentNewScreen` — `users/agent_new_screen.dart`
- Create agent: display name → auto-derived username (`derive_username`), email, contact; save → `agent.create`.

### `AnalyticsScreen` — `mobile/lib/features/analytics/analytics_screen.dart`
- Stats dashboard; preset date chips (today / 7d / 30d / custom) applied to `dashboard.analytics(from, to)` (15-min SWR); KPIs (status donut), daily trend (line/area CustomPaint), dispatch time metrics (avg/median hrs, within-24h %), Top Customers & Top Agents bars, Top Items vertical bars. Charts are custom `CustomPaint` (fl_chart unused).

### `SummaryScreen` — `mobile/lib/features/summary/summary_screen.dart`
- Stock summary: KPI cards (total sets, pieces, value ₹) + per-item rows; local `ItemSummary` computation from `item.stockList()`; `formatCurrency` (en_IN ₹). Back → `/admin/profile`.

### `BulkImportScreen` — `mobile/lib/features/bulk_import/bulk_import_screen.dart`
- Batch customer import: Download Template (xlsx via `excel`, shared), upload zone (`FilePicker` xlsx/xls/csv), parsed rows table with per-field validation (required name/contact/agent), select-all, add/delete rows, remove-failed, Import → `customer.bulkImport(payload)`; results modal. CSV parsing is custom (`_parseCsv`, key-normalization aliases e.g. name/customer name, contact/phone/mobile, gst/gstin). Back → `/admin/profile`.

### `ProfileScreen` — `mobile/lib/features/profile/profile_screen.dart`
- Shows session user (avatar, displayName, username, email, role, business) and top-right log-out button (→ session logout → auto redirect to `/login`).

---

## 8. Mobile Navigation (summary)
See §7. Keys: GoRouter flat routes + single redirect; push/go idiom; canPop fallback; bottom nav = AdminNavBar (4 tabs); Android back = pop route (preview/back buttons handled); no deep links configured (AndroidManifest has no intent-filter for deep links); data passes between screens via **route path parameters** (IDs) and via `sessionProvider` (user). On 401 or logout → session null → redirect to `/login`.

---

## 9. Mobile State Management — important flows

- **Auth flow:** login POST → session state set → router refresh → `/admin`. Persisted in Hive session box; restored at startup; forwarded to Dio.
- **Data caching flow:** repository read → `networkFirst`/`staleWhileRevalidate` → on success returns + stores; on network failure falls back to last cached JSON; API layers surface `ApiException(isNetwork:true)`.
- **Cache invalidations:** any successful write invalidates the relevant namespace so next read is fresh (e.g. order update invalidates orders/order/unpacked/dash; item update invalidates items/item/summary; agent/customer writes invalidate their namespaces).
- **Concurrency/editing flow:** the order "edit" uses backend reservation snapshot; the app just calls `start-edit`/`save-edit`/`cancel-edit` → list reloads.

---

## 10. Frontend–Backend API Communication (mobile client endpoint table)

Base URL: `AppConfig.baseUrl` = `String.fromEnvironment('API_BASE_URL', default: 'http://10.0.2.2:8000')`. Media domain: `String.fromEnvironment('MEDIA_DOMAIN')`. All requests JSON, `Authorization: Bearer`.

| Frontend service (`mobile/lib/data/repositories.dart`) | Purpose | Backend endpoint(s) |
|---|---|---|
| `AuthRepo.login` | login | `POST /api/auth/login/` |
| `AuthRepo.profile` | current profile | `GET /api/auth/profile/` |
| `AuthRepo.forgotPassword` | reset email | `POST /api/auth/forgot-password/` |
| `AuthRepo.resetPassword` | set password | `POST /api/auth/reset-password/` |
| `OrderRepo.getAll` | paged order list | `GET /api/orders/?page=…&page_size=…&search=…&from_date=&to_date=&agent=&customer=&status=` |
| `OrderRepo.getOne` | order detail | `GET /api/orders/{id}/` |
| `OrderRepo.byCustomer` | customer orders | `GET /api/orders/?customer={id}&page=…&page_size=…` |
| `OrderRepo.archived` | archived orders | `GET /api/orders/archived/` |
| `OrderRepo.getLogs` | activity logs | `GET /api/orders/{id}/logs/` |
| `OrderRepo.getViewedIds` / `allIds` | badge counts | `GET /api/orders/my-viewed-ids/` / `GET /api/orders/order-ids/` |
| `OrderRepo.markViewed` | mark read | `POST /api/orders/{id}/mark-viewed/` |
| `OrderRepo.update` | status/fields update | `PATCH /api/orders/{id}/` |
| `OrderRepo.updateItem` | edit order item | `PATCH /api/orders/order-items/{itemId}/` |
| `OrderRepo.deleteItem` | delete item | `DELETE /api/orders/{orderId}/delete-item/{itemId}/` |
| `OrderRepo.dispatch` | dispatch order | `POST /api/orders/{id}/dispatch/` |
| `OrderRepo.delete` | delete order (PIN) | `DELETE /api/orders/{id}/` (data `{pin}`) |
| `OrderRepo.unpacked` | unpacked pending items | `GET /api/orders/order-items/unpacked/` |
| `ItemRepo.sizeRanges` | size presets | `GET /api/items/size-ranges` |
| `ItemRepo.stockList` | flat stock | `GET /api/items/stock-list/` |
| `ItemRepo.archived` | stale items | `GET /api/items/archived/` |
| `ItemRepo.getOne` | item detail | `GET /api/items/{id}/` |
| `ItemRepo.byqrcode` | QR lookup | `GET /api/items/by-qr/?qr_code=…` |
| `ItemRepo.allVariants` | variant flat list | `GET /api/items/variants/all/` |
| `ItemRepo.customerRequirements` | packing needs | `GET /api/items/customer-requirements/?item_id=…` |
| `ItemRepo.createMultipart` | create item | `POST /api/items/` (multipart) |
| `ItemRepo.update` | update item | `PUT /api/items/{id}/` |
| `ItemRepo.patchVariantImage` | variant image | `PATCH /api/items/variants/{variantId}/` |
| `ItemRepo.deleteWithPin` | delete item | `DELETE /api/items/{id}/` (data `{pin}`) |
| `CustomerRepo.list` | customer list | `GET /api/customers/?page=&page_size=&search=` |
| `CustomerRepo.create/update` | CRUD | `POST /api/customers/`, `PATCH /api/customers/{id}/` |
| `CustomerRepo.bulkImport` | batch create | `POST /api/customers/bulk-import/` |
| `CustomerRepo.deleteInfo` / `delete` | delete | `GET /api/customers/{id}/delete_info/`, `DELETE /api/customers/{id}/` |
| `AgentRepo.list/getOne` | agent list/detail | `GET /api/agents/`, `GET /api/agents/{id}/` |
| `AgentRepo.create/update` | CRUD | `POST /api/agents/`, `PATCH /api/agents/{id}/` |
| `AgentRepo.deleteInfo` / `delete` | delete | `GET /api/agents/{id}/delete_info/`, `DELETE /api/agents/{id}/` |
| `AgentRepo.updateItems` | replace assignment | `POST /api/agents/{id}/items/` |
| `AgentRepo.transferItems` / `copyItems` | transfer/copy | `POST /api/agents/{id}/items/transfer/`, `.../copy/` |
| `AgentRepo.deleteAllItems` | clear assignments | `DELETE /api/agents/{id}/items/` |
| `TransportRepo.active` | transports | `GET /api/transports/active/` |
| `DashboardRepo.analytics` | analytics | `GET /api/dashboard/analytics/?from=&to=` |

(Mobile does **not** call: admin-user creation, brands, transports writes, dashboard summary, push-subscription — those are web-only today.)

---

## 11. Backend Overview — `backend/`

Django project **`config`** (`backend/config/settings.py`, `urls.py`, `wsgi.py`, `asgi.py`, `celery.py`); apps live in `backend/apps/` + top-level `backend/transports/`.

**Settings highlights** (`config/settings.py`):
- `SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS` (default `http://localhost:3000,https://stockflow-sigma.vercel.app`), `CORS_ALLOW_ALL_ORIGINS` from env via `decouple`.
- Postgres via env vars `DB_NAME/USER/PASSWORD/HOST/PORT`.
- Celery: `CELERY_BROKER_URL` (default redis://localhost:6379/0); beat schedule `celerybeat` task `cleanup-orphaned-media-daily` at 00:00 (`apps.items.tasks.cleanup_orphaned_media_task`).
- `REST_FRAMEWORK`: only JWT auth + drf-spectacular schema class. (No global permission class → DRF default `AllowAny` applies where a view doesn't set one.)
- `SIMPLE_JWT.ACCESS_TOKEN_LIFETIME = timedelta(days=30)`.
- `AUTH_USER_MODEL = "accounts.User"`.
- Media: FileSystemStorage, `MEDIA_ROOT = BASE_DIR/media`; media also served by Django `serve()` in `urls.py`. Static via whitenoise (`CompressedManifestStaticFilesStorage`).
- SMTP email backend; GST_RATE (default 5); VAPID keys for web-push.
- TIME_ZONE: set to UTC then overridden to **Asia/Kolkata**; prod security flags (SSL redirect, secure cookies, HSTS) when `DEBUG=False`.
- CORS headers: `corsheaders` + `CorsMiddleware` first in list; `CSRF_TRUSTED_ORIGINS` = https CORS origins.

**Endpoints** (`config/urls.py`): `/health/`, `/api/schema/`, `/api/docs/`, `/api/redoc/`, `/api/password/*` (django-rest-passwordreset — separate from the custom reset flow used by clients), `/admin/`, `/api/admins/`, `/api/auth/`, `/api/agents/`, `/api/customers/`, `/api/items/`, `/api/orders/`, `/api/dashboard/`, `/api/business/`, `/api/notification/`, `/api/transports/`, `/media/*`.

**Apps and their role:**

| App | Role |
|---|---|
| `accounts` | Custom `User` (roles), PIN, custom password-reset tokens, login/profile/forgot/reset views, permission classes, `seed_test_data` command |
| `agents` | `Agent` + `AgentItem` assignment; agent CRUD, item transfer/copy, push notifications to agents |
| `customers` | `Customer` CRUD, search, bulk import, soft-delete, `delete_info` |
| `items` | `Item`/`ItemVariant`/`ItemVariantSize`; stock-list, QR lookups, out-of-stock checks, customer requirements, image pipeline, signals, cleanup task |
| `orders` | Order DRAFT→…→DISPATCHED lifecycle, OrderItem edits, packing, dispatch, invoice (JSON), logs, viewed-orders |
| `dashboard` | Admin-only summary counts and analytics KPIs |
| `admins` | Create/update ADMIN users (superuser-scoped) |
| `business` | `Brand` CRUD (superuser writes), seed_brands command |
| `notification` | `PushSubscription` save + `send_push_to_user` Celery task (pywebpush) |
| `transports` | `Transport` CRUD (read public, writes staff-only) |

### Models — full fields (source: each app's `models.py`)

**User** (`accounts/models.py`) — email unique; role {ADMIN, AGENT}; business {gents, kids}; brand FK→Brand (SET_NULL, related_name `users`); display_name; pin (hashed); `save()` forces ADMIN role for superuser; `set_pin/check_pin`.
**PasswordResetToken** (`accounts/models.py`) — user FK, token unique, created_at, expires_at, used.
**Agent** (`agents/models.py`) — user OneToOne(…, CASCADE), contact, is_active, deactivated_at; `soft_delete()` (also deactivates user), `hard_delete()`.
**AgentItem** (`agents/models.py`) — agent FK (related `assigned_items`), variant FK (related `assigned_agents`), created_at, `unique_together (agent, variant)`.
**Customer** (`customers/models.py`) — name (unique), address, contact, gst, agent FK→Agent (PROTECT, related `customers`, null), preferred_transport FK→Transport (SET_NULL), is_active, deactivated_at.
**Item** (`items/models.py`) — name, description, price (Decimal 10,2), type {kids, gents}, brand FK→Brand (PROTECT, related `items`), is_deleted, out_of_stock_since.
**ItemVariant** (`items/models.py`) — item FK (related `variants`), display_order (str), qr_code UUID unique (default uuid4, editable False), image → `items/{item.id}/{filename}`.
**ItemVariantSize** (`items/models.py`) — item_variant FK (related `sizes`), size {20-24,26-30,32-36,38,S,M,L,XL,XXL}, stock (PositiveInteger, default 0), `unique_together (item_variant, size)`.
**Order** (`orders/models.py`) — customer FK (PROTECT), agent FK (PROTECT, null), status {DRAFT, PENDING, EDITING, PACKED, DISPATCHED}, expected_delivery_date, preferred_transport FK (SET_NULL, related `orders`), transport_company FK (SET_NULL, related `dispatched_orders`), lr_number, reservation_snapshot (JSON), editing_started_at, notes (max 200), created_at, dispatched_at.
**OrderItem** (`orders/models.py`) — order FK (related `items`), item FK (SET_NULL), variant FK (SET_NULL), size_group, item_type, **item_name / item_price / variant_image / size (snapshot fields)** so deleted/deleted-items history persists, quantity (PositiveInteger), packed_quantity.
**OrderLog** (`orders/models.py`) — order FK (related `logs`), action {ITEM_DELETED, ORDER_DELETED, ORDER_EDITED, DISPATCHED, EDIT_STARTED, EDIT_SAVED, EDIT_CANCELLED}, details (JSON), performed_by FK→User (SET_NULL), created_at.
**UserViewedOrder** (`orders/models.py`) — user FK, order FK, viewed_at, `unique_together (user, order)`.
**PushSubscription** (`notification/models.py`) — user FK (related `push_subscriptions`), endpoint (unique), p256dh, auth, user_agent, created_at, updated_at.
**Brand** (`business/models.py`) — name, phone, email, address_line1/2, logo → `brands/`, gst, is_active, deactivated_at, created_at, updated_at.
**Transport** (`transports/models.py`) — name, is_active, created_at.

---

## 12. Database Architecture

Engine: **PostgreSQL**. Migrations: 47 app migrations (see each app's `migrations/`). No `django_celery_beat` tables exist (beat app not installed).

**Relationships**

```
Brand 1─N Item                  Brand 1─N User (User.brand)
User (accounts) 1─1 Agent      Agent 1─N Customer (Customer.agent)
Agent M─N ItemVariant  via AgentItem (agent, variant)
Item 1─N ItemVariant 1─N ItemVariantSize (size, stock)
Order N─1 Customer, N─1 Agent   Order 1─N OrderItem (item/variant snapshot)
Order N─1 Transport (preferred_transport) ; Order N─1 Transport (transport_company/dispatched)
User M─N Order via UserViewedOrder  ;  Order 1─N OrderLog  ;  User 1─N PushSubscription
Customer N─1 Transport (preferred_transport)
```

Key facts:
- Soft-delete conventions: `is_active` + `deactivated_at` (Agent, Customer, Brand, Transport) / `is_deleted` (Item). Deleted items remain referenced by OrderItem history.
- Audit: `created_at`/`updated_at` on core entities; OrderLog is the audit trail for order changes; fields like `dispatched_at`, `editing_started_at`, `reservation_snapshot` support the order workflow.
- `ItemVariantSize.stock` is the single source of truth for stock; item/variant "total stock" is computed (sum) in endpoints, not stored.
- Unique constraints: `User.email`, `Customer.name`, `ItemVariant.qr_code`, `AgentItem(agent, variant)`, `ItemVariantSize(variant, size)`, `UserViewedOrder(user, order)`, `PushSubscription.endpoint`.
- Indexes: default FK indexes only in models (no explicit `db_index` outside FK/unique fields). Not confirmed: custom composite indexes beyond those implied by `unique_together`/FK.

---

## 13. Backend API Reference (confirmed endpoints)

Prefix everything with `/api/`. Auth: JWT Bearer unless noted. Full action list (see also mobile endpoint table §10):

| Method | Endpoint | Permission | Purpose |
|---|---|---|---|
| POST | `/auth/login/` | none | Login → {access, refresh, role, user_id, business, is_superuser} |
| GET | `/auth/profile/` | auth | Current user info |
| POST | `/auth/forgot-password/` | none | Email reset link (custom PasswordResetToken, 30-min expiry) |
| POST | `/auth/reset-password/` | none | Set new password with token |
| GET/POST | `/admins/` | IsAdmin | List/create admin users |
| GET/PUT/PATCH/DELETE | `/admins/{pk}/` | IsAdmin | Admin user CRUD (superuser semantics) |
| GET/POST | `/agents/` | IsAdminOrSelfAgent | List/create agents |
| GET/PUT/PATCH/DELETE | `/agents/{pk}/` | IsAdminOrSelfAgent | Agent CRUD (destroy: transfer/deactivate + PIN) |
| GET | `/agents/{pk}/delete_info/` | IsAdminOrSelfAgent | counts of customers/orders + transferable agents |
| GET | `/agents/profile/{user_id}/` | auth(default) | Agent by user id |
| GET/POST | `/agents/{id}/items/` | IsAdminOrSelfAgent | List / replace assignments (variant_ids) |
| DELETE | `/agents/{id}/items/` | IsAdminOrSelfAgent | Clear assignments |
| DELETE | `/agents/{id}/items/variants/{vid}/` | IsAdminOrSelfAgent | Remove one assignment |
| POST | `/agents/{id}/items/transfer/` | IsAdminOrSelfAgent | Move assignments to target agent |
| POST | `/agents/{id}/items/copy/` | IsAdminOrSelfAgent | Copy assignments to target agent |
| GET | `/customers/` | auth | List (paged 50, search) — admin all / agent own |
| POST | `/customers/` | auth | Create (agent auto-assigned to own agent) |
| GET/PUT/PATCH/DELETE | `/customers/{pk}/` | auth | Customer CRUD (delete = PIN soft-delete) |
| GET | `/customers/{pk}/delete_info/` | auth | orders_count |
| POST | `/customers/bulk-import/` | auth (csrf exempt) | Bulk create from JSON array (name+agent required; unique names) |
| GET/POST | `/items/` | read auth / write IsAdmin | List/create items |
| GET/PUT/PATCH/DELETE | `/items/{pk}/` | IsAdmin (retrieve auth) | Item CRUD (delete = PIN soft-delete; remove unreferenced images) |
| GET | `/items/stock-list/` | auth | Flat stock incl. edit-boost |
| GET | `/items/by-qr/?qr_code=` | auth | Variant lookup + availability + optional agent assignment check |
| GET | `/items/archived/` | auth | Out-of-stock >30 days items |
| GET | `/items/by-qr/out-of-stock/?qr_code=` | auth | Availability grouped by order size-ranges (with optional order_id draft reservation) |
| GET | `/items/customer-requirements/?item_id=` | auth | Packing needs (unpacked OrderItems by customer) |
| GET/POST | `/items/variants/` | read auth / write IsAdmin | Variant CRUD |
| GET/PUT/PATCH/DELETE | `/items/variants/{pk}/` | IsAdmin (retrieve auth) | Variant CRUD |
| GET | `/items/variants/all/` | auth | Flat variant list with totals |
| GET | `/items/size-ranges` | (default) | Size presets for item & order creation |
| GET/POST | `/orders/` | auth | List (filtered, paged) / create (agent = request.user.agent) |
| GET/PUT/PATCH/DELETE | `/orders/{pk}/` | auth | Order detail/update (delete = PIN + stock return) |
| POST | `/orders/{pk}/dispatch/` | auth | Dispatch (PENDING/PACKED only) |
| POST | `/orders/{pk}/cancel-edit/` | auth | Cancel EDITING order edit |
| POST | `/orders/{pk}/place-order/` | auth | DRAFT→PENDING with stock deduction |
| POST | `/orders/{pk}/add-item/` | IsAgent | Add item to DRAFT/EDITING/PENDING order |
| POST | `/orders/{pk}/start-edit/` | IsAgent | Begin edit (snapshot) |
| POST | `/orders/{pk}/save-edit/` | IsAgent | Save edit (revert+recheck+re-deduct) |
| DELETE | `/orders/{oid}/delete-item/{iid}/` | auth | Remove item (stock return if PENDING/PACKED) |
| GET | `/orders/{pk}/invoice/` | auth | Invoice data JSON |
| GET | `/orders/{pk}/logs/` | auth | Audit log entries |
| GET | `/orders/my-viewed-ids/` | auth | Viewed order ids |
| POST | `/orders/{pk}/mark-viewed/` | auth | Mark viewed |
| GET | `/orders/order-ids/` | auth | {id, status} list |
| GET | `/orders/archived/` | auth | Dispatched >30 days |
| GET/POST | `/orders/order-items/` | auth | OrderItem list/create |
| GET/PUT/PATCH/DELETE | `/orders/order-items/{pk}/` | auth | OrderItem CRUD (update does stock logic on PENDING/PACKED) |
| GET | `/orders/order-items/unpacked/` | auth | Packing queue (packed_quantity=0, PENDING) |
| GET | `/dashboard/` | IsAdmin | Summary counts + agents |
| GET | `/dashboard/analytics/?from=&to=` | IsAdmin | KPIs/trend/top lists/time metrics |
| GET/POST | `/business/` | read auth / write IsSuperuser | Brand list/create |
| GET/PUT/PATCH/DELETE | `/business/{pk}/` | IsSuperuser (retrieve auth) | Brand CRUD (delete: transfer/deactivate + PIN) |
| GET | `/business/{pk}/delete_info/` | IsSuperuser | counts + transferable brands |
| POST | `/notification/save-subscription/` | auth | Save PushSubscription (update_or_create by endpoint) |
| GET | `/transports/` | AllowAny | List |
| GET | `/transports/active/` | AllowAny | Active transports |
| POST/PUT/PATCH/DELETE | `/transports/{pk}/` | IsAdminUser | Transport write |
| GET | `/health/` | none | `{"status":"ok"}` |
| GET | `/schema/`, `/docs/`, `/redoc/` | none | drf-spectacular OpenAPI docs |
| POST | `/password/reset_password/` (+`/confirm/`) | none | django-rest-passwordreset flow (third-party; not used by mobile) |

---

## 14. Authentication & Security

- **Login** (`LoginView`): accepts `username` OR `email` + `password`; email lookup is case-insensitive; deactivated accounts rejected; issues SimpleJWT access + refresh.
- **Sessions:** stateless JWT; access token lifetime 30 days (configured); backend does **not** mount a `/token/refresh` route, and clients do **not** refresh — 401 → logout on mobile; web middleware expires cookies when the JWT `exp` is near/expired.
- **Storage:** web = httpOnly-less cookies (`token`, `auth_refresh`, `auth_user`, `role`, `business`, `is_superuser`) read by AuthContext + proxy.ts. Mobile = Hive box `session` in app documents (NOT secure storage — plaintext on device).
- **Passwords:** Django PBKDF2 hashing; PIN is separately hashed (`make_password`); password reset via emailed token (custom `PasswordResetToken`, 30-min expiry, single-use) OR third-party `django-rest-passwordreset` endpoint (unused by mobile).
- **Roles/permissions:** see §5.
- **CSRF/CORS:** CSRF middleware + `@csrf_exempt` on bulk-import; CORS allows configured origins + credentials; `CSRF_TRUSTED_ORIGINS` for https origins. Production: SSL redirect, secure cookies, HSTS preload.
- **File upload:** item images resized to ≤1024px thumbnails (Pillow); RGBA→PNG, else JPEG q80; orphan cleanup job deletes unreferenced media.
- **Secrets:** all through env vars (`SECRET_KEY`, `DB_*`, SMTP, VAPID keys — see §23). **Repo hygiene issue:** `api_client/` contains committed JWT dev tokens in plaintext (`api_client/yaak.ev_*.yaml`).

---

## 15. Inventory / Product System (in detail)

- **Item** = base product row: name, description, price, type (kids|gents), optional brand. Soft-deletable (`is_deleted`).
- **Variant** = colour of an item (later models: each variant is standalone instance with one image, one `display_order` string, a **unique UUID QR code**).
- **Size rows** = `ItemVariantSize` (size string, stock). Sizes allowed: `20-24, 26-30, 32-36, 38, S, M,L,XL, XXL`. `unique (variant, size)`.
- **Stock computation:** a variant's stock = sum of its sizes' `stock` (+ agent edit-boost). Item stock = sum across variants. Endpoints expose `total_stock`, `total_sets`, `total_pieces`.
- **Size-group mapping** (`backend/apps/orders/utils.py` `SIZE_MAPPING`) → which individual sizes a claimed "size group" covers for stock deduction. Piece counts per size group (`orders/serializers.py` `get_piece_count`) drive order totals and invoice price (price × qty × pieces per set).
- **Item creation/update API** (`CreateItemSerializer`, `UpdateItemSerializer`): accepts `variants[]` with `sizes[]`/`stock`, optional image file; create generates QR UUIDs; update diffs by variant id (new = create, missing = delete, `remove_image` clears photo). Brand required for superuser else caller's brand.
- **QR/lookup:** `by-qr` returns item+variant (optionally restricted by agent assignment); `by-qr/out-of-stock` computes per-size-group min availability for the ordering UI; QR labels are generated and printed by clients (mobile `qr_label_pdf.dart`, web react-qr-code PDF).
- **Availability rules:** `out_of_stock_since` auto-set when total stock hits 0 (signal `update_item_stock_status`), cleared when stock > 0; items out-of-stock >30 days move to "archived"; `stock-list` never subtracts anything (deduction happens only via orders).
- **Customer requirements** = remaining unpacked quantities of an item grouped by customer, for the packing workflow.

---

## 16. Order System (in detail)

**Creation:** agent selects customer → scans/browses assigned items → `AddOrderItemView` validates (item assigned to agent, single item type per order, valid size group) and adds to DRAFT order. **No stock movement at this stage.**

**Placement** (`/orders/{id}/place-order/`): DRAFT only, requires items. Within a transaction with `select_for_update` on `ItemVariantSize`, checks stock per size-row (quantity must be available for each size in the claimed size group); on failure returns `out_of_stock_items` + push notifications to agent + matched admins, 400. On success deducts via `F("stock") - quantity`, sets PENDING, optional delivery date/transport/notes, notifies admins.

**Editing:** `start-edit` (agent, PENDING, owned): snapshot into `reservation_snapshot`, set `editing_started_at`, delete viewed-marks, log EDIT_STARTED. `save-edit`: return old stock from snapshot, re-check + re-deduct current items, clear snapshot, log EDIT_SAVED. `cancel-edit` / 15-min stale revert restores snapshot and PENDING. In-item updates via `OrderItemViewSet.update` (DRAFT-free stock path) also return old stock and re-check. Status symbol: **PENDING stays PENDING while editing** unless the client PATCHes `EDITING` (the mobile/web flow PATCHes status; backend revert logic keys off `status`/`editing_started_at`). **The `StartEditView` itself does not change the `status` field** — this is a documented quirk.

**Packing:** `OrderItem.packed_quantity` per item (0 = unpacked). `/orders/order-items/unpacked/` lists PENDING items needing packing.

**Dispatch** (`/orders/{id}/dispatch/`): requires PENDING or PACKED; optional `transport_company` + `lr_number`; sets DISPATCHED + `dispatched_at`; **returns stock for unpacked** (line: `quantity - packed_quantity`, using piece-count scaling) back into `ItemVariantSize`; logs DISPATCHED; notifies agent; clears viewed marks.

**Cancellation / deletion:** no formal "cancelled" status exists. Deleting an order (PIN-gated) returns stock if it wasn't DRAFT; deleting an item returns stock when order isn't DRAFT/EDITING. Order statuses are DRAFT/PENDING/EDITING/PACKED/DISPATCHED only.

**Invoice:** JSON via `InvoiceSerializer` (customer, agent, brand, created_at, status, items, `total_price` (price×qty×pieces), `gst_rate` from settings). **No backend PDF.** The web app renders a printable PDF client-side.

**History/audit:** `OrderLog` entries (Item Deleted/Order Deleted/Order Edited/Dispatched/Edit-*), `UserViewedOrder` read-badges, and snapshotted `item_name/item_price/variant_image` on items preserve a readable order even if items are later deleted.

---

## 17. Customer / Agent System

**Customers**
- Created by admins (or agents for their own customers — `perform_create` auto-assigns the agent). Unique name; fields name/address/contact/gst/preferred transport. GST stored/displayed uppercased by clients.
- Assigned to exactly one `Agent` (nullable) — this drives agent visibility. Bulk import (JSON rows) requires name + agent username per row, rejects duplicate names and unknown/inactive transports, returns `{created, failed, errors}`.
- Paged searchable list; admin sees all (business-scoped "has business orders" flag), agent sees only own. Soft delete via PIN.

**Agents**
- Created with a User (role AGENT) + contact. `AgentItem` records which variants the agent may order from. Admin can replace the whole assignment set, transfer to another agent, copy to another agent, clear, or scan QR to add single variants.
- `AgentDetail`/Agent profile endpoint keyed by user id; lists grouped assigned items with size/stock.
- Deletion: deactivate (soft) OR transfer-and-hard-delete (moves customers to a target agent then deletes agent + user). Both PIN-gated for admins.
- Agent data access is backend-scoped to their own orders/customers/assignments.

---

## 18. Image & File Storage

- **Storage backend:** Django `FileSystemStorage`, `MEDIA_ROOT = backend/media/`. Folders: `media/items/{item_id}/` (variant images), `media/brands/` (brand logos).
- **Upload pipeline:** `CreateItemSerializer._save_variant_image` (Pillow): resize to ≤1024×1024 thumbnail; transparent (RGBA/P/LA) → PNG optimized, else RGB → JPEG quality 80; filename = random hex; any existing variant image is replaced/deleted first.
- **URLs:** backend builds absolute URLs via `request.build_absolute_uri(request)`; clients recompute with `resolveImageUrl`. Web `NEXT_PUBLIC_MEDIA_DOMAIN`; mobile `MEDIA_DOMAIN` → `https://$MEDIA_DOMAIN/path`; production example `api.xlapparals.in`.
- **Serving:** debug — Django `serve()` in `urls.py`; production — media dir volume-shared with the web container (docker `./media:/app/media`) and served by Django (there is no dedicated CDN/Nginx media rule in compose; static is whitenoise).
- **Deletion:** item destroy physically removes image files of variants unless referenced by OrderItems; `cleanup_orphaned_media` management command + daily Celery task delete unreferenced files older than `--days-old` (default 0) in `MEDIA_ROOT/items`, keeping files referenced by live variants OR by OrderItem history; also prunes empty subfolders.
- **Caching on devices:** `cached_network_image` disk+memory cache; offline reads may show cached thumbnails; mobile image preview reuses the same URL for cache hits.
- **Inconsistency to note:** images are **variant-level** (one photo per colour), but item cards/aggregates expose the first variant's image as the "item image".

---

## 19. Realtime / WebSocket System

**No WebSockets and no realtime data push exist in the backend.** Realtime-adjacent features:
- **Web push notifications** (`apps/notification`): `PushSubscription` saved by web clients (`SaveSubscriptionView`); `send_push_to_user` Celery task sends push via `pywebpush` with VAPID keys on (a) out-of-stock at place-order, (b) order placed (to admins), (c) items assigned (to agent), (d) dispatch (to agent). Config: `vapid_claims.sub = mailto:muhammedmuflih9605@gmail.com`, `ttl=86400`, `urgency=high`. Dead subscriptions (404/410) are deleted.
- The web app ships a **service worker** (`frontend/public/sw.js`) for push; the mobile app has no push receiver.
- **Polling pattern:** mobile refreshes on connectivity changes and manual pull-to-refresh; early sessions use short TTL cache revalidation (2–15 min) — effectively near-realtime, not push.

---

## 20. Background Tasks

- **Celery** (`config/celery.py`): worker only; `autodiscover_tasks` finds tasks in installed apps.
- **Beat schedule** (`settings.CELERY_BEAT_SCHEDULE`): `cleanup-orphaned-media-daily` at midnight → `apps.items.tasks.cleanup_orphaned_media_task()` → runs `manage.py cleanup_orphaned_media --days-old 1`.
- **`send_push_to_user`** (notification task) — see §19.
- **Known deployment bug:** `docker-compose.yml` beat container uses `--scheduler django_celery_beat.schedulers:DatabaseScheduler` but **`django-celery-beat` is not installed / not in INSTALLED_APPS** → beat fails as configured. Also `REDIS_URL` env (in compose) is never read by the app (broker comes only from `CELERY_BROKER_URL`).

---

## 21. Tally / External Integrations

**No Tally integration exists anywhere in this repo** (no ODBC, no Tally HTTP APIs, no desktop agent; this was verified by directory/import inspection). External integrations that DO exist: **SMTP email** (password reset), **Web Push** (VAPID/pywebpush), **Stripe/payments: none**, mobile **print/share** (pdf, printing, share_plus, open_filex), **file parsing** (excel/csv import), and **Vercel hosting** for the web app.

---

## 22. Deployment Architecture

**Backend** — `backend/docker-compose.yml` (all services use env file `.env`):
- **db**: `postgres:16-alpine`, volume `pgdata:/var/lib/postgresql/data`, `POSTGRES_*` env.
- **redis**: `redis:7-alpine`, appendonly, volume `redisdata:/data`.
- **celery**: `celery -A config worker -l info`, shares `./media:/app/media`.
- **celery-beat**: `celery -A config beat -l info --scheduler django_celery_beat...` (see bug §20).
- **web**: builds `backend/Dockerfile` (python:3.12-slim, gunicorn `--bind 0.0.0.0:8000 --workers=2 --timeout=120 --access-logfile - --error-logfile - config.wsgi:application`, runs `migrate --noinput` then gunicorn; `collectstatic` at build via whitenoise). Exposed only on `127.0.0.1:8000` (reverse-proxy expected in front).

```
Internet
  ├── Web app → Vercel (stockflow-sigma.vercel.app) → Django API (HTTPS, CORS)
  └── Mobile app (APK) → Django API
                      ▼
              Nginx / reverse proxy (in front of 127.0.0.1:8000; assumed, not in repo)
                      ▼
              Django / Gunicorn (web container)
                   ├── PostgreSQL 16
                   ├── Redis 7
                   └── Celery worker + beat
```

- **Web frontend:** Vercel deployment covering `(auth)(agent)(admin)(admin-no-layout)` routes; domain defaults in CORS config; media domain `api.xlapparals.in` (from mobile SETUP.md). No Docker for the web app.
- **Mobile:** Flutter Android build; release currently signed with the **debug keystore** (TODO in `build.gradle.kts`).
- **Backups/restore:** no backup scripts present in the repo (not confirmed). Restore would be standard Postgres dump/restore.
- **SSL:** production Django enables SSL redirect/HSTS when `DEBUG=False`; cipher setup expected at the reverse proxy layer.

---

## 23. Environment Variables

**Backend** (`backend/.env.example`):

| Variable | Purpose | Required | Secret? |
|---|---|---|---|
| `DEBUG` | Debug flag | Yes | No |
| `SECRET_KEY` | Django secret | Yes | **Yes** |
| `ALLOWED_HOSTS` | comma-separated hosts | Yes | No |
| `CORS_ALLOWED_ORIGINS` | allowed web origins | No (has default) | No |
| `CORS_ALLOW_ALL_ORIGINS` | allow any origin | No | No |
| `DB_NAME` / `DB_USER` / `DB_PASSWORD` / `DB_HOST` / `DB_PORT` | Postgres connection | Yes | Password **Yes** |
| `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | Postgres container init | Yes | Password **Yes** |
| `EMAIL_HOST` / `EMAIL_PORT` / `EMAIL_USE_TLS` / `EMAIL_HOST_USER` / `EMAIL_HOST_PASSWORD` / `DEFAULT_FROM_EMAIL` | SMTP for password reset | No | Password **Yes** |
| `PUBLIC_VAPID_KEY` / `PRIVATE_VAPID_KEY` | Web push VAPID | No | Private **Yes** |
| `CELERY_BROKER_URL` | Redis URL for Celery | No (default `redis://localhost:6379/0`) | No |
| `GST_RATE` | GST percent used on invoices (settings read; default 5) | No | No |

(`REDIS_URL` is set in compose but unused by code.)

**Web frontend** (`frontend/AGENTS.md`): `NEXT_PUBLIC_API_BASE_URL` (default `http://localhost:8000`), `NEXT_PUBLIC_MEDIA_DOMAIN`. **Mobile** — compile-time defines: `API_BASE_URL` (default `http://10.0.2.2:8000`), `MEDIA_DOMAIN` (optional).

---

## 24. Project File / Folder Structure (source-relevant only)

```
stock_flow/
├─ README.md                     # marketing summary
├─ PROJECT_OVERVIEW_FOR_CHATGPT.md   # this document
├─ backend/                      # Django REST API (uv-managed, Python 3.12)
│  ├─ config/                    # settings, urls, wsgi/asgi, celery
│  ├─ apps/
│  │  ├─ accounts/               # User, auth views, permissions, seed_test_data
│  │  ├─ admins/                 # admin-user management (superuser-scoped)
│  │  ├─ agents/                 # Agent + assignment + transfer/copy
│  │  ├─ business/               # Brand + seed_brands
│  │  ├─ customers/              # Customer + bulk import
│  │  ├─ dashboard/              # summary + analytics
│  │  ├─ items/                  # Item/Variant/Size, stock, QR, images, signals, tasks
│  │  ├─ notification/           # PushSubscription + push task
│  │  └─ orders/                 # order lifecycle, editing, dispatch, invoice, logs
│  ├─ transports/                # Transport model (read public / write staff)
│  ├─ media/                     # uploaded images (items/, brands/)
│  ├─ seed_data/                 # seed brand logos + test images
│  ├─ pyproject.toml / uv.lock / requirements.txt(Docker)
│  ├─ Dockerfile  .env.example  docker-compose.yml  manage.py
├─ frontend/                     # Next.js 16 web app (admin + agent)
│  ├─ app/                       # route groups (auth)(agent)(agent-order)(admin)(admin-no-layout)
│  ├─ components/                # shadcn/ui + items/order/pages components
│  ├─ lib/api/                   # axios modules (auth, admin, agents, brand, customer, dashboard, item, order, transport)
│  ├─ context/ hooks/ util/ types/ constants/
│  ├─ public/sw.js               # push service worker
│  ├─ proxy.ts                   # Next middleware (role + token expiry)
│  └─ AGENTS.md  next.config.ts  tailwind.css etc.
├─ mobile/                       # Flutter admin app (stock_flow_admin)
│  ├─ lib/
│  │  ├─ main.dart  app.dart  providers.dart
│  │  ├─ core/     # api/api_client.dart, cache/app_cache.dart, config/app_config.dart,
│  │  │            # router/app_router.dart, theme/app_theme.dart, utils/* (formatters, piece_counts, status_maps, stock_validators, derive_username)
│  │  ├─ data/repositories.dart  models/models.dart
│  │  ├─ features/  # auth, dashboard, orders, items, users, analytics, summary, bulk_import, profile
│  │  └─ shared/    # widgets.dart, admin_shell.dart
│  ├─ test/         # helpers + 5 test files
│  ├─ android/      # Gradle / manifest (AGP 8.7.3; cleartext enabled)
│  ├─ pubspec.yaml  SETUP.md
├─ api_client/                  # Yaak (API client) export — 46 YAML dev requests + env (has committed tokens)
└─ docs/                        # only opengraph.jpg
```

---

## 25. Business Rules That Must Not Be Broken

1. **Stock must never go negative.** Deductions happen only in `PlaceOrderView`/`SaveEditView`/`OrderItemViewSet.update` with `select_for_update` and a pre-check; on shortfall return 400 with `out_of_stock_items` and notify (no partial deduction).
2. **Adding a line to DRAFT/EDITING order never touches stock;** stock moves only at placement/save-edit/dispatch-unpacked/delete.
3. **Order lifecycle transitions:** DRAFT→PENDING (place), PENDING→PACKED/PENDING→DISPATCHED (dispatch needs PENDING or PACKED), DISPATCHED terminal (excluded from main list after 30 days → "archived").
4. **Dispatch returns warehouse stock for the unpacked portion**; packed portion stays counted.
5. **Agents may only order items assigned to them** (`AgentItem`) and only their own orders/customers are visible (backend-enforced). Ownership checks: `order.agent.user == request.user`.
6. **An order may contain only one item type (kids XOR gents)** — enforced at add-item.
7. **Non-superuser admin business isolation:** an admin whose `business` is set only sees/operates on that type (orders, items, dashboard, analytics, requirements, logs/invoice).
8. **Destructive admin actions require a PIN** (`check_admin_pin`) for deleting orders, items, customers, agents, brands. Superusers and agents bypass.
9. **Soft-delete everywhere:** agents/customers/brands use `is_active`+`deactivated_at`; items use `is_deleted`; only agent transfer path hard-deletes.
10. **Customer names are globally unique**; bulk import rejects duplicates.
11. **Out-of-stock items (>30 days) vanish from normal lists** and appear only under "archived".
12. **Stale-edit auto-recovery:** DRAFT orders >15 min deleted; EDITING >15 min reverted to PENDING.
13. **Order history must survive item deletion** → snapshot `item_name/item_price/variant_image/variant qr` on OrderItem.
14. **Size usage is size-group based:** a size_group maps to specific size rows (SIZE_MAPPING); piece-count scaling (`price × qty × pcs`) drives totals/invoices.
15. **Invoice is JSON from backend** (GST from `GST_RATE`); PDF rendering is a client concern.
16. **Item edit reconciles variants** — variants absent from the update payload are deleted; new ones created; `remove_image` clears a photo.
17. **Agents receive the business-dedicated admin notification set** (admins whose `brand`+`business` match) on placement/out-of-stock; agents get dispatch/assignment notifications.
18. **Deactivated users cannot place/log in** (`user.is_active` checks in login + agent soft-delete flips it).
19. **One customer ↔ one agent** (nullable). Revenue/scoping is by that relation.
20. **Mobile is admin-only** (client-side reject of non-ADMIN login) — a UI/dev decision, not a backend permission.

---

## 26. Design System / UI Guidelines

**Brand:** XL Apparals. Primary orange `#FF6200` on white; Google Font **Plus Jakarta Sans** (mobile) / default Tailwind sans (web).

Mobile conventions (`mobile/lib/core/theme/app_theme.dart`, shared widgets `mobile/lib/shared/widgets.dart`):
- Colors: `primary #FF6200`, `pending #FF0000`, `dispatched #096700`, borders `#D9D9D9`, text muted `#919191`, headings `#111827`/black, status badge palettes (pending amber `#D97706`/`#FFFBEB`, packed orange `#EA580C`/`#FFF7ED`, dispatched green `#15803D`/`#F0FDF4`, gray `#4B5563`/`#F9FAFB`), scaffold white, card border `#EBEBEB`.
- Cards: white, elevation 0, radius 10, hairline border; section labels uppercase bold; pills/tabs: orange active pill, gray inactive; buttons: primary/outline/text + destructive red `#DC2626`; radius 10; status badges pill-shaped with uppercase text.
- Typography: headlineLarge 32/w600, headlineMedium 24/w700, titleMedium 16, bodyMedium 13, bodySmall 11 muted, label area 13/w600; numbers often w700/w800/w900.
- Nav: bottom nav floating frosted-white rounded bar (4 tabs), active = orange pill; header rows with avatar (initials, deterministic palette by id), titles 18/w800.
- Feedback: `AppToast` (top-right sonner-style overlay), `PageLoading` spinner, `EmptyState` icon+title+subtitle(+action), `RefreshIndicator` pull-to-refresh, `OfflineBanner`, `PinDialog` for destructive ops, `DeleteWithTransferDialog` (transfer-vs-deactivate), `confirmDialog`.
- Every screen uses `AdminScaffold(activePath, title, titleTrailing)` with SafeArea-aware header + optional bottom nav; status-bar overlay style dark-on-transparent.

Web (Tailwind v4 CSS-first `frontend/app/globals.css`, shadcn/ui new-york, font default) — mirrors the same palette; components include `StatusBadge`, `StockFlowButton`, chat-style Modals. Match these conventions when adding features; a redesign was not requested.

---

## 27. Current Features Checklist

### Implemented (confirmed in code)
- [x] Admin + Agent JWT login (username/email + password), forgot/reset password (email token).
- [x] Role-based auth (ADMIN/AGENT/superuser) backend-enforced; business isolation.
- [x] Items with multi-variants, per-variant QR, images (Pillow pipeline), sizes + stock.
- [x] Size-groups → size mapping; piece-count pricing/totals.
- [x] Order lifecycle DRAFT→PENDING→PACKED→DISPATCHED + EDITING sub-state edit/save/cancel.
- [x] Stock deduction on placement, auto-return on delete/dispatch-unpacked/edit-revert; negative-stock guard with push notifications.
- [x] Archived lists (orders >30d dispatched; items out-of-stock >30d).
- [x] Order audit logs + viewed/unread marks.
- [x] Invoice data endpoint (JSON + GST) and web-side PDF.
- [x] Agents CRUD + item assignment (replace/transfer/copy/clear/QR-scan).
- [x] Customers CRUD + search + pagination + bulk import (xlsx/xls/csv) + per-admin scoping.
- [x] Brands CRUD (superuser) + delete transfer/deactivate.
- [x] Transports CRUD + active list.
- [x] Dashboard summary (order counts + agent customer counts) and Analytics (KPIs/trend/top lists/dispatch time metrics).
- [x] Inventory Stock/Ordered views, stock-summary screen, QR printing (web + mobile PDFs), QR scanning (web + mobile).
- [x] Web push notifications (VAPID) for order-like events.
- [x] Admin-only Flutter mobile app mirroring the web admin (orders, items, users, analytics, summary, bulk import, profile; offline cache).
- [x] Swagger/ReDoc + OpenAPI schema endpoints.
- [x] Celery daily orphaned-media cleanup.

### Partially implemented / gaps
- [ ] `StartEditView` doesn't set `status=EDITING` itself (relies on client PATCH) — documented quirk.
- [ ] Celery **beat** as dockerized is misconfigured (`django-celery-beat` not installed).
- [ ] Mobile `OrderEditStubScreen` is a lightweight stub (full edit parity lives on the status screen).
- [ ] Mobile `fl_chart` dependency present but unused (charts are CustomPaint).
- [ ] Mobile has no Settings/Admins tabs, no agent-side PDF export, no superuser flows (deliberate per `mobile/SETUP.md`).
- [ ] Auth "refresh" token issued but no `/token/refresh` endpoint/client flow.
- [ ] Web: middle layer `proxy.ts` role gate + AuthContext (client cookies only, no SSR session).
- [ ] `permission_handler` dependency present in mobile but unused (camera handled by MobileScanner).
- [ ] Cross-version comment: `transports` migrations generated under Django 4.2.24 while others are 5.2.x.

### Not implemented / missing
- [ ] No Tally/accounting integration (nothing in repo).
- [ ] No WebSockets/realtime channel.
- [ ] No refunds/payments/outstanding-balance tracking on orders.
- [ ] No formal cancellation status (only delete).
- [ ] No backend PDF/invoice generation (client-side only).
- [ ] No dark theme anywhere.
- [ ] No automated CI/CD config in the repo; no backup/restore scripts; no production reverse-proxy config in repo.

---

## 28. Known Bugs / Technical Debt / Concerns

**Confirmed from code:**
1. `accounts/permissions.py:13` — leftover `print(f"Role {request.user.role}")` debug output in `IsAdmin.has_permission`.
2. `items/views.py:198-213` — duplicated QR lookup try/except block; second block is dead (first `except Exception` already returns "Invalid QR code").
3. `docker-compose.yml` celery-beat uses a scheduler whose package (`django-celery-beat`) is **not installed** → beat will crash if started that way.
4. `REDIS_URL` env in compose is unused (broker only reads `CELERY_BROKER_URL`).
5. Repo hygiene: `api_client/yaak.ev_*.yaml` contains committed, apparently live JWT bearer tokens (dev) in plaintext.
6. `settings.py` sets `TIME_ZONE` twice ("UTC" then "Asia/Kolkata"); final value is Asia/Kolkata.
7. Mobile release build is signed with the **debug key** (TODO in `mobile/android/app/build.gradle.kts`).
8. Mobile build currently requires `--android-skip-build-dependency-validation` on this machine (AGP 8.7.3 vs Flutter's minimum 8.11.1).
9. Transports migrations say Django 4.2.24 while the rest are 5.2.x (minor inconsistency; historical).
10. Mobile tokens stored in plaintext Hive box (`session`), not secure storage.

**Known TODOs in code:**
- `mobile/android/app/build.gradle.kts` — applicationId/signing "TODO: specify your own unique Application ID" (applicationId is set; signing still debug).
- `not-found.tsx` / misc generated boilerplate comments across both apps.

**Potential concerns (not confirmed bugs):**
- `OrderViewSet.perform_create` sets `agent=self.request.user.agent` — an ADMIN user creating an order via the ViewSet would raise `AttributeError`; in practice order creation flows through the DRAFT/agent flows.
- Deleting an item's image files only happens when no OrderItem references the variant; combined with `post_delete` signal and the orphan-cleaner, double-deletion is guarded but subtle.
- `update_item_stock_status` (ItemVariantSize post-save) recomputes an aggregate `Sum` on **every** size save, even if stock didn't change (perf note; not a defect).
- CORS allows any origin if `CORS_ALLOW_ALL_ORIGINS=true`; used in dev.
- No rate limiting on auth endpoints observed.
- Payment/outstanding not tracked anywhere.

---

## 29. Important Files

| File | Why it matters |
|---|---|
| `backend/config/settings.py` | Everything configured (env, DB, JWT, Celery beat, CORS, storage, GST) |
| `backend/config/urls.py` | Root API route map |
| `backend/apps/orders/views.py` | Core order lifecycle logic (place, edit, dispatch, delete, invoice, logs) |
| `backend/apps/orders/serializers.py` | Order/OrderItem/Invoice serialization; piece-count logic |
| `backend/apps/orders/utils.py` | SIZE_MAPPING / size-group math |
| `backend/apps/items/views.py` | Inventory, stock-list, QR, out-of-stock, requirements |
| `backend/apps/items/serializers.py` | Item/variant create+update with image pipeline |
| `backend/apps/items/signals.py` + `tasks.py` | Out-of-stock flagging; orphan-media cleanup |
| `backend/apps/accounts/permissions.py` + `views.py` | Auth endpoints + permission classes + PIN helper |
| `backend/apps/agents/views.py` | Agent CRUD + assignment transfer/copy |
| `backend/apps/customers/views.py` | Customer list + bulk import |
| `backend/apps/dashboard/views.py` | Summary + analytics |
| `backend/apps/notification/tasks.py` | Web-push task (VAPID) |
| `backend/apps/*/models.py` | The whole schema (see §12) |
| `frontend/app/(admin)/admin/**` , `frontend/app/(agent)/**` | Web screens |
| `frontend/lib/api/*` | Web API client modules |
| `frontend/proxy.ts`, `frontend/context/AuthContext.tsx` | Web auth gate (cookies) |
| `mobile/lib/main.dart`, `app.dart`, `providers.dart` | Mobile bootstrap + session state |
| `mobile/lib/core/router/app_router.dart` | Mobile routes + redirect |
| `mobile/lib/core/api/api_client.dart`, `data/repositories.dart` | Mobile HTTP layer + endpoint map |
| `mobile/lib/core/cache/app_cache.dart` | Hive caching + invalidation |
| `mobile/lib/shared/widgets.dart`, `admin_shell.dart` | Reusable UI kit / scaffold / nav |
| `mobile/lib/features/*/*.dart` | All mobile screens (see §7) |
| `mobile/SETUP.md` | How to run the mobile app |

---

## 30. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│   Clients                                                   │
│  ┌───────────────┐   ┌────────────────────┐   ┌──────────┐  │
│  │ Flutter Admin │   │ Next.js 16 Web App │   │ Yaak     │  │
│  │  (mobile/)    │   │ admin + agent      │   │ (dev API │  │
│  │  Riverpod/Dio │   │ (frontend/)        │   │ client)  │  │
│  └───────┬───────┘   └─────────┬──────────┘   └──────────┘  │
│          │ JWT Bearer          │ JWT cookies / Bearer        │
└──────────┼─────────────────────┼─────────────────────────────┘
           ▼                     ▼
      ┌────────────────────────────────────────────┐
      │  Nginx / reverse proxy (expected in prod)  │
      └────────────────────┬───────────────────────┘
                           ▼
        ┌────────────────────────────────────┐
        │ Django 5.2 / DRF 3.16 / Gunicorn  │
        │  apps: accounts, agents, customers,│
        │  items, orders, dashboard, admins, │
        │  business, notification, transports│
        └───────┬────────────────────┬───────┘
                │                    │
                ▼                    ▼
        PostgreSQL 16  ┌────────────────────────┐
                │       │ Redis 7 ──► Celery     │
                │       │   worker + beat        │
                │       │   (cleanup, web-push)  │
                │       └────────────────────────┘
                ▼
        MEDIA (filesystem /media + whitenoise static)
```

---

## 31. Data Flow Examples

**Login (mobile):** `LoginScreen` → `sessionProvider.notifier.login` → `Repositories.auth.login` → `Dio POST /api/auth/login/` → `LoginView` authenticates → SimpleJWT `{access, refresh, role, user_id, business, is_superuser}` → `Session` persisted to Hive `session` → token set on Dio → router refresh → `/admin`.

**Create an item (add variant+image):** `ItemWizardScreen` → `item.createMultipart` (FormData) → `POST /api/items/` → `CreateItemSerializer.create` (brand resolution, variant QR generation, `_save_variant_image` resize/encoding, sizes creation) → `Item` + variants + size rows persisted → response → invalidate `items/item/summary` caches → stock lists refresh.

**Place an order (agent):** web/mobile `PlaceOrderView` flow → backend: `transaction.atomic()` + `select_for_update` per size row → stock check → deduct via `F("stock") - quantity` → `status=PENDING` → commit → `OrderLog`/push to admins → updated stock appears in `/stock-list`.

**Dispatch:** `OrderStatusScreen` → `order.dispatch` → `POST /orders/{id}/dispatch/` → guard PENDING/PACKED → returns unpacked stock (piece-count scaling) → sets DISPATCHED + `dispatched_at` + transport → pushes agent → list refresh; >30 days later appears only under `/orders/archived/`.

**Image upload (edit variant):** `ItemEditScreen` picks image → `item.update` (existing image kept) → `patchVariantImage` PATCH → `_save_variant_image` replaces stored file → new URL served at `/media/items/{item_id}/…`; old file deleted.

---

## 32. Instructions for Future AI-Assisted Development

1. Inspect the existing code for the module you're changing before writing anything (read models, views, repositories, screens).
2. Reuse existing architecture: Riverpod `SessionController` + repository pattern + `AppCache` on mobile; axios `lib/api/*` + AuthContext on web; DRF ViewSets/Serializers/`IsAdmin`-style permission classes on backend.
3. Do not create duplicate services/components (there's already `api_client.dart`+`repositories.dart` mobile, `lib/api` web).
4. Preserve the existing UI/design (colors, radii, tabs, badges, toasts) unless a redesign was explicitly requested.
5. Preserve business rules in §25 — especially stock/`select_for_update` semantics, size-group math, PIN deletes, business isolation, soft-deletes, and the DRAFT→PENDING→PACKED→DISPATCHED lifecycle.
6. Do not change API contracts unnecessarily; prefer additive (new endpoint/field) changes. If a contract must change, update BOTH clients and the OpenAPI schema.
7. When a feature crosses the API boundary, check BOTH the Django endpoint(s) and the matching repository method + screen(s).
8. When changing models, create a Django migration; keep migration history git-tracked.
9. Never expose secrets: no SECRET_KEY, DB passwords, VAPID strings, SMTP credentials, or JWT tokens in code/docs/commits (there is past evidence of tokens committed in `api_client/` — do not add more).
10. Run `flutter analyze` + `flutter test` (mobile), `pnpm lint`/`tsc --noEmit` + `pnpm test:run` (web), and backend checks after changes.
11. Avoid unnecessary refactoring; keep changes minimal and clean.
12. Identify shared components first (`mobile/lib/shared/widgets.dart`, `admin_shell.dart`; web `components/ui/*`).
13. Consider role/permission implications (ADMIN vs AGENT vs superuser, business isolation, PIN) for every feature.
14. Consider mobile responsiveness + offline/cache behavior (Hive TTL, networkFirst fallbacks).
15. For the mobile app, keep parity with the web admin where screens mirror each other.
16. Mind the documented quirks: `start-edit` status quirk, beat scheduler bug, transport 4.2 migration, admin `perform_create` agent assumption.

---

## 33. How Future ChatGPT Should Handle Update Requests

When the user asks for a feature/update, produce:
1. A short requirements restatement, and ask clarifying questions if ambiguous.
2. Affected **frontend/mobile screens** (names from §7 / web route tree).
3. Affected **backend APIs** (endpoints from §13).
4. Affected **models/tables** (§12) + migration requirement.
5. Affected **roles/permissions** (§5) and PIN/business-isolation implications.
6. **Reusable components** (shared widgets, repositories, serializers) to use instead of duplicating.
7. **Side effects** (stock, cache invalidation namespaces, notifications, item/variant reconciliation).
8. A clear implementation prompt for a coding AI: which files to read first, what to change, what NOT to change, and testing steps (`flutter analyze`, `flutter test`, backend tests, manual API checks, OpenAPI refresh).

---

## 34. Research Integrity

Compiled from direct inspection of the source code (backend apps + config, mobile lib, frontend app/lib, docker/env files). Anything unverifiable is marked. No feature/endpoint/relationship was invented.

---

## 35. Source References

All key statements carry inline file references (see earlier sections). Primary anchors:
- Backend routes: `backend/config/urls.py`; per-app `urls.py`.
- Auth: `backend/apps/accounts/{views,serializers,permissions,models}.py`.
- Orders: `backend/apps/orders/{views,serializers,utils,models}.py`.
- Items: `backend/apps/items/{views,serializers,signals,tasks,models}.py`.
- Agents/customers: `backend/apps/{agents,customers}/{views,serializers,models}.py`.
- Dashboard/business/notification: `backend/apps/{dashboard,business,notification}/`.
- Transport: `backend/transports/`.
- Settings/deploy: `backend/config/settings.py`, `backend/docker-compose.yml`, `backend/Dockerfile`, `backend/.env.example`.
- Mobile: `mobile/lib/core/**`, `mobile/lib/data/repositories.dart`, `mobile/lib/models/models.dart`, `mobile/lib/shared/**`, `mobile/lib/features/**`.
- Web: `frontend/proxy.ts`, `frontend/context/AuthContext.tsx`, `frontend/lib/api/**`, `frontend/app/**`.

---

## 36. Current Project Status

- **Working:** full backend API; web admin + agent UX; mobile admin app (orders, inventory, users, analytics, summary, bulk import, QR print, offline cache); auth + forgot/reset; stock integrity; approvals flows.
- **Partially working:** Celery beat docker config (bug), mobile order edit (stub), mobile missing superuser/settings screens, mobile missing agent features (PDF export).
- **Unfinished / not present:** Tally/payments/outstanding, WebSocket realtime, backend PDFs, CI/CD, backups, dark theme.
- **Known bugs / debt:** see §28.
- **Operator notes for this machine:** mobile builds need `--android-skip-build-dependency-validation` (AGP mismatch); backend runs against a local Postgres/Redis + Django dev server on `:8000`; emulator reaches host via `10.0.2.2`.

---

## 37. AI QUICK CONTEXT

**Product:** Stock Flow — B2B garment order-management platform for XL Apparals. Warehouse admins manage items (multi-colour variants, size-stock, QR), agents build orders by scanning assigned items; orders flow DRAFT→PENDING→PACKED→DISPATCHED with strict, transactional stock control and audit logs, plus analytics and dispatch/transport tracking.

**Tech stack:** Django 5.2 + DRF + SimpleJWT + PostgreSQL + Redis/Celery + Web Push backend; Next.js 16/React 19 web app (admin+agent); Flutter admin app (Riverpod, go_router, Dio, Hive CE); Docker Compose; Vercel web hosting.

**Roles:** superuser (brands/provisioning), ADMIN (warehouse ops; business-isolated by gents/kids; PIN-gated deletes), AGENT (own orders/customers + assigned items only).

**Modules:** Items/Variants/Stock & QR, Orders (+edit reservation +pack +dispatch +invoice JSON +logs), Users (admins/agents/customers + bulk import), Brands, Transports, Dashboard/Analytics, Notifications (web push), Inventory summaries, QR label printing, mobile offline cache.

**Architecture:** `backend/` (config + 9 apps + transports) ← JSON JWT ← `frontend/` (Next) and `mobile/` (Flutter). Media on local filesystem; images resized to ≤1024px by backend.

**Key invariants:** stock never negative (transactional deduction only at place/save-edit; return on dispatch-unpacked/delete); agents only order assigned items; single item-type per order; admin business isolation; PIN for destructive deletes; soft deletes; out-of-stock >30d → archived; DRAFT>15min cleaned / EDITING>15min reverted; size-group→size-row math drives stock and prices.

**Screens (mobile admin):** Login/Forgot/Reset; Orders dashboard (tabs All/Pending/Packed/Dispatched + filters); Order status (pack/dispatch/edit/logs); Inventory (InStock/OutOfStock/Ordered + QR scan + image preview); Item wizard (3 steps) / edit; Ordered-items; QR print/label; Users (customers/agents) hub + customer/agent detail + new; Analytics (charts); Summary; Bulk Import; Profile. (Web additionally: agent ordering UI, brands/transports settings, admins management.)

**Important files:** see §29.

**Status:** active development; notable caveats in §27–§28 (beat scheduler bug, debug print, dup QR block, committed dev tokens in `api_client/`, AGP mismatch, debug-signed release APK, mobile tokens in plaintext Hive).

**Development rules:** mirror existing conventions; respect §25 invariants; keep migrations; update both clients when API changes; run analyzer/tests; never commit secrets.