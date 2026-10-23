# Graph Report - stock_flow  (2026-10-23)

## Corpus Check
- 524 files · ~327,879 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 138 file(s) not represented in the graph (top: .gz 112, (none) 9, .xml 9)

## Summary
- 4736 nodes · 9813 edges · 188 communities (126 shown, 62 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 455 edges (avg confidence: 0.94)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b94b1e99`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Orders API & Lifecycle
- Database Migrations
- Mobile Models & Domain Helpers
- StockFlowButton
- Mobile Shared Widgets
- Mobile Dashboard Screens
- Mobile Order & Item Cards
- orders/tests.py
- agent/order/new/[id]/[qr]/page.tsx
- Mobile Repository Layer
- Item
- Agent
- lucide-react
- ../core/theme/app_theme.dart
- addColor.tsx
- Mobile Order Creation
- Mobile Agent Management
- Mobile Inventory & Sync
- agent_new_screen.dart
- Mobile Analytics Screen
- Mobile Screen Controllers
- Mobile Stock Summary
- customer_new_screen.dart
- Web Agent Order Types
- Mobile Bulk Import
- Mobile Item Creation Wizard
- Mobile Item Editing
- Mobile App Shell & Auth UI
- Mobile Test Fixtures
- package:go_router/go_router.dart
- useAuth
- Mobile Size & Piece Math
- ItemList.tsx
- qr_print_select_screen.dart
- Mobile Order Item Selection
- Mobile Customer Detail
- Mobile Item Sync Store
- ImagePreview.tsx
- Mobile Hive Cache
- Mobile QR Label PDF
- Mobile Profile & Archives
- Mobile Order QR Scanner
- Web Build Config
- accounts/views.py
- Order Edit Tests
- Django App Registry
- _SummaryScreenState
- Mobile Customer Selection
- QR Label Fit Test
- Mobile Formatters
- ItemEditMatrixAPITests
- item_analytics_screen.dart
- Mobile Domain Models
- item_categories_screen.dart
- Draft Order Tests
- Mobile Item Sync Service
- customers/views.py
- Mobile Ordered Items
- Web Dependencies Manifest
- notification/tasks.py
- agent_analytics_screen.dart
- Mobile Push Notifications
- Item Purge & Cleanup
- Mobile Route Registry
- order_status_packing_test.dart
- Mobile Dio API Client
- items/edit/[id]/page.tsx
- Mobile Theme
- package:flutter_test/flutter_test.dart
- widgets_smoke_test.dart
- react
- Mobile Summary Tests
- ../../shared/widgets.dart
- Mobile Bootstrap & Providers
- get_auth_header
- Mobile Order Flow Utils
- State
- devDependencies
- QRPageContent.tsx
- PageLoading
- types/item.ts
- Web Image Utilities
- package:flutter/material.dart
- FCM Token Tests
- Web Bulk Import
- Web Component Config
- agent_detail_lazy_items_test.dart
- Web TypeScript Config
- Command
- Draft Accept Tests
- Notification Resilience Tests
- Analytics Tests
- Mobile Price Input
- Customer Tests
- OrderSerializer
- Edit Business Scope Tests
- Postgres Row Lock Tests
- Route /admin/items
- Mobile Perf Integration Test
- Agent Item QR Tests
- OrderSnapshotAfterPurgeAPITests
- OrderFlowContext.tsx
- Mobile Scan Beep
- colorList.tsx
- Draft Reject Tests
- Mobile Perf Utils
- Mobile Display Order Utils
- next
- Web Root Layout
- package:go_router/go_router.dart
- Web NPM Scripts
- Verify PIN Tests
- AnalyticsAgentBreakdownTests
- Mobile Text Symbols
- sessionProvider
- cropModal.tsx
- submitItem.ts
- Route /admin
- AssignedItemsPDF.tsx
- item-api.test.ts
- Draft Retrieve Tests
- Mobile App Config
- date-picker.tsx
- Key Features
- ImagePreview
- AdminNonDraftActionTests
- Stock Flow Mobile (Android Admin App)
- manage.py
- build
- Web Auth Middleware
- connectivityProvider
- Android MainActivity
- summary/page.tsx
- Web Size Constants
- EditModeBanner.tsx
- frontend/AGENTS.md
- AdminAnalyticsView
- Web PostCSS Config
- status_maps.dart
- agents/[id]/page.tsx
- alert.tsx
- VariantRow.tsx
- SizeRangeContext.tsx
- Yaak Password Request
- Django Project Package
- frontend/README.md
- stock_flow_admin
- AGENTS.md
- SizeRangeContext.tsx
- ItemSyncService
- SimpleBrandSerializer
- _OrderCreateScreenState

## God Nodes (most connected - your core abstractions)
1. `get_auth_header()` - 114 edges
2. `react` - 113 edges
3. `lucide-react` - 98 edges
4. `cn()` - 81 edges
5. `Order` - 76 edges
6. `next` - 73 edges
7. `PageLoading()` - 71 edges
8. `StockFlowButton()` - 63 edges
9. `toastError()` - 63 edges
10. `Agent` - 59 edges

## Surprising Connections (you probably didn't know these)
- `GET /admins/ (Show All Admins)` --references--> `User`  [INFERRED]
  api_client/yaak.rq_9C3cAmMRvy.yaml → backend/apps/accounts/models.py
- `POST /admins/ (Register Admin)` --references--> `User`  [INFERRED]
  api_client/yaak.rq_FjuFmjxnh9.yaml → backend/apps/accounts/models.py
- `GET /admins/1 (Show 1 Admin)` --references--> `User`  [INFERRED]
  api_client/yaak.rq_JYKUD58Qbv.yaml → backend/apps/accounts/models.py
- `PATCH /admins/1/ (Partial Update)` --references--> `User`  [INFERRED]
  api_client/yaak.rq_m3R8MSCQc6.yaml → backend/apps/accounts/models.py
- `DELETE /admins/4/ (Delete Admin)` --references--> `User`  [INFERRED]
  api_client/yaak.rq_qxw2B3UMST.yaml → backend/apps/accounts/models.py

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Incremental Stock Sync Pipeline** — mobile_lib_features_items_item_sync_service_itemsyncservice, mobile_lib_data_item_store_itemstore, backend_apps_items_views_itemviewset_items_sync, backend_apps_items_models_item, docs_incremental_stock_sync_report_catalog_updated_at_cursor [INFERRED 0.85]
- **Order Edit Reservation Cycle** — backend_apps_orders_views_starteditview, backend_apps_orders_views_saveeditview, backend_apps_orders_views_orderviewset_cancel_edit, backend_apps_orders_views_return_stock_for_item, backend_apps_orders_models_order [INFERRED 0.90]
- **Order Placement Stock Transaction** — backend_apps_orders_views_placeorderview, backend_apps_orders_views_stock_shortages, backend_apps_orders_views_deduct_stock_for_item, backend_apps_items_models_itemvariantsize, backend_apps_orders_models_orderitem, backend_apps_items_signals_update_item_stock_status [INFERRED 0.95]

## Communities (188 total, 62 thin omitted)

### Community 0 - "Orders API & Lifecycle"
Cohesion: 0.04
Nodes (49): GET /orders/9/invoice (Invoive), POST /orders/1/add-item/ (Add Item), DELETE /orders/16/ (Delete order), POST /orders/ (Register orders), GET /orders/ (Show All orders), PATCH /orders/2/ (Partial Update), GET /orders/1 (Show 1 orders), admin_business() (+41 more)

### Community 1 - "Database Migrations"
Cohesion: 0.02
Nodes (57): Migration, Migration, Migration, Migration, Migration, Migration, Migration, Migration (+49 more)

### Community 2 - "Mobile Models & Domain Helpers"
Cohesion: 0.02
Nodes (124): access, action, address, agentAnalytics, agentName, agents, asInt, assignedItems (+116 more)

### Community 3 - "StockFlowButton"
Cohesion: 0.12
Nodes (54): ItemCategoriesPage(), BrandDetailPage(), NewBrandPage(), EditTransportPage(), NewTransportPage(), NewAdminPage(), AgentDetailPage(), getColorFromId() (+46 more)

### Community 4 - "Mobile Shared Widgets"
Cohesion: 0.02
Nodes (89): action, appImageDecodeSide, AppToast, _avatarPalette, borderColor, borderRadius, color, _colorFromId (+81 more)

### Community 5 - "Mobile Dashboard Screens"
Cohesion: 0.02
Nodes (99): _acceptDraft, _actingDrafts, activeCount, AdminTab, _agentDropdown, _agentFilter, _agents, _bannerDismissed (+91 more)

### Community 6 - "Mobile Order & Item Cards"
Cohesion: 0.02
Nodes (97): _EmptyCardBody, _TrendPainter, _FilterToggleChip, _OrderCardView, PageArrowButton, _PaginationBar, _UnreadFilterChip, CartListChildren (+89 more)

### Community 7 - "orders/tests.py"
Cohesion: 0.05
Nodes (29): Command, AgentItemAssignNotifyResilienceTests, BrandAdmin, Command, Brand, BrandSerializer, Meta, ItemVariant (+21 more)

### Community 8 - "agent/order/new/[id]/[qr]/page.tsx"
Cohesion: 0.15
Nodes (22): EditProductDetailPage(), ProductHeader(), ProductHeaderProps, ProductImage(), ProductImageProps, ProductInfo(), ProductInfoProps, QuantitySelector() (+14 more)

### Community 9 - "Mobile Repository Layer"
Cohesion: 0.02
Nodes (84): acceptDraft, active, addItem, agent, AgentRepo, allVariants, analytics, archived (+76 more)

### Community 10 - "Item"
Cohesion: 0.06
Nodes (32): PUT /items/2/ (Update 1 order), GET /items/size-ranges/ (Size Range), DELETE /items/1/ (Delete Item), POST /items/ (Register Items), PATCH /items/2/ (Partial Update), PUT /items/2/ (Update 1 item), GET /items/by-qr/ (Fetch With QR), GET /items/ (Show All Items) (+24 more)

### Community 11 - "Agent"
Cohesion: 0.03
Nodes (44): GET /admins/ (Show All Admins), PUT /agents/1/ (Update 1 Agent), POST /admins/ (Register Admin), GET /agents/profile/2, GET /admins/1 (Show 1 Admin), GET /agents/ (Get All Agents), PATCH /admins/1/ (Partial Update), GET /agents/1/ (get 1 Agent) (+36 more)

### Community 12 - "lucide-react"
Cohesion: 0.08
Nodes (33): Page(), SettingsPage(), Tab, Page(), OrderDetailHeader(), OrderDetailHeaderProps, BrandsList(), TransportsList() (+25 more)

### Community 13 - "../core/theme/app_theme.dart"
Cohesion: 0.04
Nodes (43): build, StockFlowApp, routerProvider, build, createState, dispose, _email, _error (+35 more)

### Community 14 - "addColor.tsx"
Cohesion: 0.10
Nodes (38): Step2AddColor(), Step1CommonDetails(), blankVariant(), NewItemPage(), uid(), AdminDetailPage(), getColorFromId(), Home() (+30 more)

### Community 15 - "Mobile Order Creation"
Cohesion: 0.03
Nodes (56): _addItem, build, _cardDecoration, _confirmMerge, createState, _customer, _customerCard, customerId (+48 more)

### Community 16 - "Mobile Agent Management"
Cohesion: 0.03
Nodes (64): _agent, agentId, agentName, _agents, _allVariants, _AssignScanSheet, _AssignScanSheetState, _AssignTab (+56 more)

### Community 17 - "Mobile Inventory & Sync"
Cohesion: 0.03
Nodes (60): active, build, children, _clearFilters, createState, disabled, dispose, _done (+52 more)

### Community 18 - "agent_new_screen.dart"
Cohesion: 0.08
Nodes (21): AgentNewScreen, _AgentNewScreenState, _contactCtrl, createState, dispose, _emailCtrl, _emailRegex, _existingUsernames (+13 more)

### Community 19 - "Mobile Analytics Screen"
Cohesion: 0.04
Nodes (52): _AnalyticsPreset, _applyCustom, _applyPreset, _body, build, _card, centered, createState (+44 more)

### Community 20 - "Mobile Screen Controllers"
Cohesion: 0.05
Nodes (48): AnalyticsScreen, _AnalyticsScreenState, DashboardScreen, _DashboardScreenState, ItemEditScreen, _ItemEditScreenState, ItemWizardScreen, _ItemWizardScreenState (+40 more)

### Community 21 - "Mobile Stock Summary"
Cohesion: 0.03
Nodes (57): _breakdownRow, cmp, _compareNumeric, ComputedSummary, computeSummary, _content, createState, dispose (+49 more)

### Community 22 - "customer_new_screen.dart"
Cohesion: 0.06
Nodes (34): _body, _deleteAgent, _saveDetails, build, _body, _delete, _save, _addressCtrl (+26 more)

### Community 23 - "Web Agent Order Types"
Cohesion: 0.07
Nodes (42): AdminHomePage(), AdminHomePageContent(), SimpleAgent, Tab, OrderCard(), OrderCardProps, statusConfig, EMPTY_LABELS (+34 more)

### Community 24 - "Mobile Bulk Import"
Cohesion: 0.04
Nodes (46): _addRow, _BackendError, _backendErrors, _badge, BulkImportScreen, _BulkImportScreenState, _cellText, _clearAll (+38 more)

### Community 25 - "Mobile Item Creation Wizard"
Cohesion: 0.04
Nodes (49): _backFromForm, _blankVariant, build, _categories, _categoriesLoading, _category, _ColorCardTile, _CommonBadgeEdit (+41 more)

### Community 26 - "Mobile Item Editing"
Cohesion: 0.04
Nodes (47): _avatarBlock, backendId, build, _buildGroups, capitalized, _categories, _category, createState (+39 more)

### Community 27 - "Mobile App Shell & Auth UI"
Cohesion: 0.08
Nodes (23): AuthAlert, AuthBranding, AuthCard, AuthSubmitButton, autofocus, build, children, controller (+15 more)

### Community 28 - "Mobile Test Fixtures"
Cohesion: 0.04
Nodes (43): agentDetailJson, agentJson, analyticsJson, asSyncItem, binding, customerJson, customerRequirementsJson, dioAdapter (+35 more)

### Community 29 - "package:go_router/go_router.dart"
Cohesion: 0.11
Nodes (17): build, _classify, createState, dispose, _email, _emailError, _errorSub, _errorTitle (+9 more)

### Community 30 - "useAuth"
Cohesion: 0.14
Nodes (28): CustomersPage(), Tab, AgentCustomersPage(), AdminsList(), AgentsList(), CustomerList(), CacheMeta, clearCache() (+20 more)

### Community 31 - "Mobile Size & Piece Math"
Cohesion: 0.04
Nodes (43): kGentsSizes, kKidsSizes, kSizeRangePieceCount, kSizeRangeToSizes, null, pieceCountFor, singleSizeRangeFor, build (+35 more)

### Community 32 - "ItemList.tsx"
Cohesion: 0.16
Nodes (23): getItemImage(), hasOutOfStockVariants(), ItemCard(), ItemCardProps, filterItems(), ItemList(), ItemListProps, OrderedItemList() (+15 more)

### Community 33 - "qr_print_select_screen.dart"
Cohesion: 0.06
Nodes (32): QrLabel, _buildPdf, _category, createState, _error, _fabric, initState, _itemName (+24 more)

### Community 34 - "Mobile Order Item Selection"
Cohesion: 0.05
Nodes (42): _autoSelectSizeGroup, _availableStock, _back, build, byType, _content, createState, customerId (+34 more)

### Community 35 - "Mobile Customer Detail"
Cohesion: 0.04
Nodes (43): indexed, isOrderItemFullyPacked, sortOrderItemsUnpackedFirst, totalPieces, ArchivedItemCard, build, expanded, item (+35 more)

### Community 36 - "Mobile Item Sync Store"
Cohesion: 0.05
Nodes (30): adoptServerTime, applyStockRow, applyStockRows, archiveAfterDays, archiveCutoff, _box, check, clearStore (+22 more)

### Community 37 - "ImagePreview.tsx"
Cohesion: 0.10
Nodes (30): AdminAnalyticsPage(), AgentHorizontalBarChart(), AgentHorizontalBarChartProps, CustomerBarChart(), CustomerBarChartProps, ItemBarChart(), ItemBarChartProps, KpiTilesProps (+22 more)

### Community 38 - "Mobile Hive Cache"
Cohesion: 0.05
Nodes (34): AppCache, cacheBox, cacheBoxName, _cacheLog, clearAll, clearItemSync, clearSession, _evictOldest (+26 more)

### Community 39 - "Mobile QR Label PDF"
Cohesion: 0.05
Nodes (33): _buildPrintAllPage, buildQrLabelsPdf, _buildSinglePage, byteData, canvas, caption, category, displayOrder (+25 more)

### Community 40 - "Mobile Profile & Archives"
Cohesion: 0.06
Nodes (29): _Action, _actionCard, _actionRow, _archivedItems, _archivedOrderRow, _archivedOrders, _archivesLoading, _archivesTab (+21 more)

### Community 41 - "Mobile Order QR Scanner"
Cohesion: 0.10
Nodes (21): _applyQuery, _backToOrder, _body, build, createState, customerId, _entries, _error (+13 more)

### Community 42 - "Web Build Config"
Cohesion: 0.06
Nodes (35): eslintConfig, engines, node, name, packageManager, private, version, config (+27 more)

### Community 43 - "accounts/views.py"
Cohesion: 0.12
Nodes (16): POST /auth/login/ (Login), PasswordResetToken, Meta, LoginRequestSerializer, LoginResponseSerializer, UserCreateSerializer, Meta, UserSerializer (+8 more)

### Community 44 - "Order Edit Tests"
Cohesion: 0.10
Nodes (5): AdminPerformCreateTests, get_auth_header(), OrderEditFlowTests, PatchGuardTests, UnpackedOrderItemsSuccessTests

### Community 45 - "Django App Registry"
Cohesion: 0.06
Nodes (10): AccountsConfig, AdminsConfig, AgentsConfig, BusinessConfig, CustomersConfig, DashboardConfig, ItemsConfig, NotificationConfig (+2 more)

### Community 47 - "Mobile Customer Selection"
Cohesion: 0.04
Nodes (40): _body, build, createState, _creating, _customers, _customerTile, _debounce, dispose (+32 more)

### Community 48 - "QR Label Fit Test"
Cohesion: 0.06
Nodes (25): a, concat, _contentStreams, _draw, _Drawn, kinds, _longName, main (+17 more)

### Community 49 - "Mobile Formatters"
Cohesion: 0.09
Nodes (18): activeFilterCount, _apiDate, archiveCountdownLabel, count, date, _displayDate, formatDate, formatDateShort (+10 more)

### Community 51 - "item_analytics_screen.dart"
Cohesion: 0.07
Nodes (30): _applyRange, _body, build, createState, _data, _dateField, _dateFilterBar, _draftFrom (+22 more)

### Community 52 - "Mobile Domain Models"
Cohesion: 0.06
Nodes (35): Agent, AgentAnalyticsRow, AgentAnalyticsSummary, AgentItemVariant, AgentUser, AnalyticsData, AnalyticsKpis, AssignedItem (+27 more)

### Community 53 - "item_categories_screen.dart"
Cohesion: 0.07
Nodes (28): _categoryField, _addCard, _addCategory, _body, build, _busyId, _cancelEdit, _categories (+20 more)

### Community 54 - "Draft Order Tests"
Cohesion: 0.11
Nodes (5): AdminAbandonedDraftListTests, AdminDraftVisibilityTests, DraftOwnershipTests, DraftSweepTests, OrderIdsCountTests

### Community 55 - "Mobile Item Sync Service"
Cohesion: 0.06
Nodes (24): attach, _attached, _bootstrap, _delta, detach, didChangeAppLifecycleState, _handleFailure, _inFlight (+16 more)

### Community 56 - "customers/views.py"
Cohesion: 0.05
Nodes (22): GET /customers/ (Show All Customers), PATCH /customers/2/ (Partial Update), PUT /customers/2/ (Update 1Customer), DELETE /customers/2/ (Delete Admin), POST /customers/ (Register Customers), GET /customers/1 (Show 1 customers), AgentDeleteInfoTests, Customer (+14 more)

### Community 57 - "Mobile Ordered Items"
Cohesion: 0.07
Nodes (30): createState, customer, customerCount, customerName, _CustomerRow, _customers, _error, _ErrorState (+22 more)

### Community 58 - "Web Dependencies Manifest"
Cohesion: 0.07
Nodes (30): dependencies, axios, class-variance-authority, clsx, date-fns, heic2any, js-cookie, lucide-react (+22 more)

### Community 59 - "notification/tasks.py"
Cohesion: 0.10
Nodes (9): DeviceToken, PushSubscription, _get_fcm_app(), send_fcm_to_user(), send_push_to_user(), queue_safely(), RegisterDeviceTokenView, SaveSubscriptionView (+1 more)

### Community 60 - "agent_analytics_screen.dart"
Cohesion: 0.09
Nodes (21): AgentAnalyticsScreen, _AgentAnalyticsScreenState, _agentList, _agentRow, _applyRange, _body, build, createState (+13 more)

### Community 61 - "Mobile Push Notifications"
Cohesion: 0.07
Nodes (20): _available, init, _initialized, instance, itemId, _local, message, notification (+12 more)

### Community 62 - "Item Purge & Cleanup"
Cohesion: 0.09
Nodes (10): Command, ArchivedItemRecord, delete_item_keep_history(), purge_archived_items(), _purge_eligibility(), purge_threshold(), PurgeResult, cleanup_orphaned_media_task() (+2 more)

### Community 64 - "order_status_packing_test.dart"
Cohesion: 0.06
Nodes (27): base, counter, deriveUsername, username, count, status, unpackedLineCount, every (+19 more)

### Community 65 - "Mobile Dio API Client"
Cohesion: 0.08
Nodes (19): ApiClient, data, dio, _extractMessage, hasToken, init, isNetwork, kPerfStartKey (+11 more)

### Community 66 - "items/edit/[id]/page.tsx"
Cohesion: 0.22
Nodes (14): DisplayOrderField(), DisplayOrderFieldProps, EditVariantRow(), Props, ItemEditPage(), blankVariant(), uid(), Accordion() (+6 more)

### Community 67 - "Mobile Theme"
Cohesion: 0.08
Nodes (23): AppColors, AppTheme, border, cardBorder, dispatched, dispatchedBg, dispatchedFg, grayBg (+15 more)

### Community 68 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.05
Nodes (21): _analyticsPayload, container, main, _item, main, name, price, type (+13 more)

### Community 69 - "widgets_smoke_test.dart"
Cohesion: 0.07
Nodes (12): _analyticsPayload, container, _kpiTiles, main, _analyticsPayload, container, main, trendPaintFinder (+4 more)

### Community 70 - "react"
Cohesion: 0.07
Nodes (51): ForgotPassword(), Status, classifyError(), ERROR_MESSAGES, ErrorType, Login(), ResetPasswordForm(), ResetPasswordPage() (+43 more)

### Community 71 - "Mobile Summary Tests"
Cohesion: 0.12
Nodes (14): container, lastEditLocation, main, manyStockEntries, mockItemOneFor, names, null, pumpAndSettle (+6 more)

### Community 72 - "../../shared/widgets.dart"
Cohesion: 0.11
Nodes (17): _appliedFrom, _appliedTo, _apply, _applying, build, busy, createState, _dateField (+9 more)

### Community 73 - "Mobile Bootstrap & Providers"
Cohesion: 0.09
Nodes (14): container, init, Session, build, conn, _current, isOnline, login (+6 more)

### Community 74 - "get_auth_header"
Cohesion: 0.11
Nodes (6): AdminDraftItemLookupTests, CustomerRequirementsIsolationTests, CustomerRequirementsSuccessTests, get_auth_header(), ItemSyncAPITests, _make_order_item()

### Community 75 - "Mobile Order Flow Utils"
Cohesion: 0.09
Nodes (19): availableSizeRanges, availableStockForSizeGroup, clear, computeDuplicateGroups, customerId, groups, itemName, map (+11 more)

### Community 76 - "State"
Cohesion: 0.12
Nodes (22): AnalyticsDateRangeBar, _AnalyticsDateRangeBarState, PasswordField, _PasswordFieldState, _CustomerPickerSheet, _CustomerPickerSheetState, _DraftCardView, _DraftCardViewState (+14 more)

### Community 77 - "devDependencies"
Cohesion: 0.11
Nodes (19): devDependencies, eslint, eslint-config-next, jsdom, openapi-typescript, tailwindcss, @tailwindcss/postcss, @testing-library/dom (+11 more)

### Community 78 - "QRPageContent.tsx"
Cohesion: 0.14
Nodes (16): QRPrintPage(), formatDate(), formatTime(), InvoicePDF(), styles, Item, QRLabelPdf(), QRLabelPdfProps (+8 more)

### Community 79 - "PageLoading"
Cohesion: 0.06
Nodes (55): AdminNewOrderPage(), EditOrderPage(), EditOrderPage(), LoadError, OrderDetailsPage(), InvoicePage(), urlToDataUrl(), DeleteConfirmDialog() (+47 more)

### Community 80 - "types/item.ts"
Cohesion: 0.09
Nodes (30): CustomerRequirementsPage(), getAvailableSizeRanges(), getSizeGroupStock(), PriceCheckScannerPage(), SizeRangeRowProps, itemApi, SizeRangeResponse, ApiError (+22 more)

### Community 81 - "Web Image Utilities"
Cohesion: 0.28
Nodes (9): computeShrinkSize(), JPEG_QUALITY, MAX_UPLOAD_SIDE, ShrinkSize, createImage(), getCroppedImg(), isActuallyHeic(), normalizeImageFile() (+1 more)

### Community 82 - "package:flutter/material.dart"
Cohesion: 0.05
Nodes (32): StockFlowButton, main, _analyticsPayload, container, _datePayload, main, payload, _pickDate (+24 more)

### Community 83 - "FCM Token Tests"
Cohesion: 0.10
Nodes (4): DeviceTokenEndpointTests, get_auth_header(), NotifyDispatchTests, SendFcmTaskTests

### Community 84 - "Web Bulk Import"
Cohesion: 0.15
Nodes (17): BackendError, BulkImportPage(), ColumnDef, COLUMNS, CustomerRow, EditableCell(), emptyRow(), ErrorMap (+9 more)

### Community 85 - "Web Component Config"
Cohesion: 0.11
Nodes (18): aliases, components, hooks, lib, ui, utils, iconLibrary, registries (+10 more)

### Community 86 - "agent_detail_lazy_items_test.dart"
Cohesion: 0.14
Nodes (11): agent, agentWithAssignedItems, allVariants, assignedCount, container, main, mockAgentDetail, _name (+3 more)

### Community 87 - "Web TypeScript Config"
Cohesion: 0.11
Nodes (18): compilerOptions, allowJs, esModuleInterop, incremental, isolatedModules, jsx, lib, module (+10 more)

### Community 90 - "Notification Resilience Tests"
Cohesion: 0.19
Nodes (3): AnalyticsDraftTests, NotifyFailureResilienceTests, StockDepletionNotifyTests

### Community 92 - "Mobile Price Input"
Cohesion: 0.12
Nodes (14): decDigits, formatEditUpdate, hasDot, intDigits, kMaxItemPrice, kMaxPriceDecimalDigits, kMaxPriceIntegerDigits, out (+6 more)

### Community 93 - "Customer Tests"
Cohesion: 0.21
Nodes (3): CustomerCreateNotifyTests, CustomerListAdminTests, get_auth_header()

### Community 94 - "OrderSerializer"
Cohesion: 0.14
Nodes (4): OrderItemSerializer, Meta, OrderSerializer, Meta

### Community 97 - "Route /admin/items"
Cohesion: 0.22
Nodes (8): _confirmDeletePin, _editHeader, _save, _commonStep, _submit, build, build, build

### Community 98 - "Mobile Perf Integration Test"
Cohesion: 0.13
Nodes (11): _busyCount, deadline, main, navLabel, pump, _pumpUntil, sw, _tabTtc (+3 more)

### Community 100 - "OrderSnapshotAfterPurgeAPITests"
Cohesion: 0.11
Nodes (4): ArchivedItemsAPITests, ItemCreateMultipartAPITests, ManualDeleteRegressionTests, OrderSnapshotAfterPurgeAPITests

### Community 101 - "OrderFlowContext.tsx"
Cohesion: 0.23
Nodes (11): AdminNewOrderLayout(), OrderLayout(), OrderFlowContext, OrderFlowContextValue, OrderFlowProvider(), ADMIN_ORDER_BASE_PATH, AGENT_ORDER_BASE_PATH, buildOrderCreatePayload() (+3 more)

### Community 102 - "Mobile Scan Beep"
Cohesion: 0.15
Nodes (7): _beepPlayer, _playBeep, playConfirmBeep, playScanBeep, main, _new, _old

### Community 103 - "colorList.tsx"
Cohesion: 0.29
Nodes (10): Props, ColorCard(), Props, ColorListScreen(), Props, Props, CommonDetailsBadge(), Props (+2 more)

### Community 105 - "Mobile Perf Utils"
Cohesion: 0.17
Nodes (7): enabled, end, log, Perf, _releaseEnabled, start, _sw

### Community 106 - "Mobile Display Order Utils"
Cohesion: 0.17
Nodes (11): colorNumberLabel, compareItemNamesAsc, compareItemNamesDesc, n, _numRegex, parsed, ta, tb (+3 more)

### Community 107 - "next"
Cohesion: 0.09
Nodes (20): AdminLayout(), History(), MyItemsPage(), normalizeAgentItem(), Profile(), EditOrderScannerPage(), OrderScannerPage(), NewOrder() (+12 more)

### Community 108 - "Web Root Layout"
Cohesion: 0.24
Nodes (8): jakartha, metadata, RootLayout(), viewport, ServiceWorkerRegister(), AuthProvider(), initializeAuth(), sonner

### Community 109 - "package:go_router/go_router.dart"
Cohesion: 0.05
Nodes (35): ApiException, customerName, draftOrderJson, draftsBody, expiresIn, main, includeAllTab, kDispatchedInList (+27 more)

### Community 110 - "Web NPM Scripts"
Cohesion: 0.20
Nodes (10): scripts, build, dev, lint, local, mobile, start, test (+2 more)

### Community 111 - "Verify PIN Tests"
Cohesion: 0.36
Nodes (3): get_auth_header(), make_admin(), VerifyPinTests

### Community 113 - "Mobile Text Symbols"
Cohesion: 0.22
Nodes (8): kArrow, kBullet, kEllipsis, kEmDash, kEnDash, kMiddleDot, kMultiply, kRupee

### Community 114 - "sessionProvider"
Cohesion: 0.18
Nodes (8): routeObserver, _login, _handleDelete, initState, build, _handleLogout, _loadProfile, sessionProvider

### Community 115 - "cropModal.tsx"
Cohesion: 0.33
Nodes (10): ASPECTS, CropModal(), Props, getCroppedFile(), getFitFile(), hasTransparency(), loadImage(), shrinkCanvas() (+2 more)

### Community 117 - "submitItem.ts"
Cohesion: 0.16
Nodes (4): qrcode, @testing-library/react, @vitejs/plugin-react, vitest

### Community 118 - "Route /admin"
Cohesion: 0.18
Nodes (10): _goBack, _messageScaffold, _errorScaffold, _handleLeave, _place, build, _deleteOrder, _showDispatchDialog (+2 more)

### Community 119 - "AssignedItemsPDF.tsx"
Cohesion: 0.43
Nodes (6): AssignedItemsPDF(), AssignedItemsPDFProps, PDFVariant, styles, totalStock(), variantPieces()

### Community 120 - "item-api.test.ts"
Cohesion: 0.36
Nodes (4): clearFormDataContentType(), itemToFormData(), objectToFormData(), appendFormData()

### Community 122 - "Mobile App Config"
Cohesion: 0.33
Nodes (4): AppConfig, baseUrl, mediaDomain, resolveImageUrl

### Community 123 - "date-picker.tsx"
Cohesion: 0.21
Nodes (11): Preset, RangePresets(), RangePresetsProps, Button(), buttonVariants, Calendar(), CalendarDayButton(), DatePicker() (+3 more)

### Community 124 - "Key Features"
Cohesion: 0.18
Nodes (10): Access Control, Admin Dashboard, Inventory Management, Key Features, Order Management, Sales Agent Tools, Stock Flow, Tech Stack (+2 more)

### Community 125 - "ImagePreview"
Cohesion: 0.29
Nodes (13): ImagePreview(), ImagePreviewProps, Props, ShareImageButton(), Dialog(), DialogContent(), DialogDescription(), DialogHeader() (+5 more)

### Community 127 - "Stock Flow Mobile (Android Admin App)"
Cohesion: 0.25
Nodes (7): 1. Scaffold the Android platform, 2. Android manifest tweaks, 3. Dependencies, 4. Run / build, 5. Verify, Notes / known parity gaps, Stock Flow Mobile (Android Admin App)

### Community 129 - "build"
Cohesion: 0.50
Nodes (3): build, build, build

### Community 130 - "Web Auth Middleware"
Cohesion: 0.67
Nodes (3): config, isTokenExpired(), proxy()

### Community 131 - "connectivityProvider"
Cohesion: 0.67
Nodes (3): connectivityProvider, build, OfflineBanner

### Community 133 - "summary/page.tsx"
Cohesion: 0.21
Nodes (14): ComputedSummary, computeSummary(), formatCurrency(), getPieceCount(), getSortName(), ItemSummary, normalizeAdminItem(), SINGLE_SIZE_PIECE_COUNT (+6 more)

### Community 136 - "frontend/AGENTS.md"
Cohesion: 0.40
Nodes (3): Architecture, Commands, Conventions

### Community 141 - "status_maps.dart"
Cohesion: 0.25
Nodes (5): from, OrderStatus, statusBadgeColors, statusBarColor, unknown

### Community 142 - "agents/[id]/page.tsx"
Cohesion: 0.09
Nodes (34): Profile(), ActionRow(), EmptyState(), InfoRow(), ProfilePage(), SectionHeader(), Tab, stockflowAvatarProps (+26 more)

### Community 143 - "alert.tsx"
Cohesion: 0.42
Nodes (7): Alert(), AlertDescription(), AlertTitle(), alertVariants, AlertDestructive(), AlertDestructiveProps, class-variance-authority

### Community 144 - "VariantRow.tsx"
Cohesion: 0.15
Nodes (15): ItemsPage(), StockTab, OrderedItemGroup, OrderedItemListProps, StockBadge(), StockBadgeProps, deriveSizeGroups(), VariantRow() (+7 more)

### Community 145 - "SizeRangeContext.tsx"
Cohesion: 0.43
Nodes (4): NoLayout(), SizeRangeContext, SizeRangeProvider(), setSizeRanges()

### Community 182 - "SizeRangeContext.tsx"
Cohesion: 0.35
Nodes (10): MainLayout(), NavBar(), NavButton(), askNotificationPermission(), getOrCreateSubscription(), registerServiceWorker(), urlBase64ToUint8Array(), validateVapidKey() (+2 more)

### Community 183 - "ItemSyncService"
Cohesion: 0.40
Nodes (4): Delta Sync with Checksum Reconcile, ItemStore, ItemSyncData, ItemSyncService

## Knowledge Gaps
- **1864 isolated node(s):** `stock_flow_backend`, `date-fns`, `react-dom`, `sharp`, `web-push` (+1859 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2684 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **62 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Order` connect `Web Agent Order Types` to `accounts/views.py`, `Mobile Domain Models`, `agents/[id]/page.tsx`, `PageLoading`?**
  _High betweenness centrality (0.339) - this node is a cross-community bridge._
- **Are the 60 inferred relationships involving `Order` (e.g. with `GET /orders/9/invoice (Invoive)` and `POST /orders/1/add-item/ (Add Item)`) actually correct?**
  _`Order` has 60 INFERRED edges - model-reasoned connections that need verification._
- **What connects `stock_flow_backend`, `date-fns`, `react-dom` to the rest of the system?**
  _1864 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Orders API & Lifecycle` be split into smaller, more focused modules?**
  _Cohesion score 0.04096669613910993 - nodes in this community are weakly interconnected._
- **Why does `Stock Flow Three-Tier Architecture` connect `Mobile Domain Models` to `Orders API & Lifecycle`, `Web Agent Order Types`?**
  _High betweenness centrality (0.232) - this node is a cross-community bridge._
- **Should `Database Migrations` be split into smaller, more focused modules?**
  _Cohesion score 0.02074740657417823 - nodes in this community are weakly interconnected._
- **Why does `Order` connect `Mobile Domain Models` to `Mobile Models & Domain Helpers`, `accounts/views.py`?**
  _High betweenness centrality (0.226) - this node is a cross-community bridge._