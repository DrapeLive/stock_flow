# Graph Report - stock_flow  (2026-10-22)

## Corpus Check
- 517 files · ~321,222 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 137 file(s) not represented in the graph (top: .gz 112, (none) 9, .xml 9)

## Summary
- 4578 nodes · 9538 edges · 182 communities (121 shown, 61 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 444 edges (avg confidence: 0.94)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b94b1e99`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Orders API & Lifecycle
- Database Migrations
- Mobile Models & Domain Helpers
- Web UI Component Props
- Mobile Shared Widgets
- Mobile Dashboard Screens
- Mobile Order & Item Cards
- ItemVariantSize
- types/item.ts
- Mobile Repository Layer
- Item
- Agent
- items/views.py
- Web Domain Types
- admin/order/status/[id]/page.tsx
- Mobile Order Creation
- Mobile Agent Management
- Mobile Inventory & Sync
- User
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
- next
- Web User API Types
- Mobile Size & Piece Math
- Web Items UI
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
- Authentication API
- Order Edit Tests
- Django App Registry
- package:go_router/go_router.dart
- Mobile Customer Selection
- QR Label Fit Test
- Mobile Formatters
- package:flutter_test/flutter_test.dart
- Mobile Unit Tests
- Mobile Domain Models
- analytics_trend_test.dart
- Draft Order Tests
- Mobile Item Sync Service
- Web Product Order UI
- Mobile Ordered Items
- Web Dependencies Manifest
- Push Notification Backend
- Mobile Order Edit Tests
- Mobile Push Notifications
- Item Purge & Cleanup
- Mobile Route Registry
- Web Layouts & Navigation
- Mobile Dio API Client
- Web Item Assignment PDF
- Mobile Theme
- Mobile Dashboard Tests
- Item Edit Matrix Tests
- react
- Mobile Summary Tests
- Mobile Username & Packing Utils
- Mobile Bootstrap & Providers
- get_auth_header
- Mobile Order Flow Utils
- Mobile Shared Dialogs
- lucide-react
- agent_new_screen.dart
- PageLoading
- variant_image_source_test.dart
- Web Image Utilities
- ordered_items_test.dart
- FCM Token Tests
- Web Bulk Import
- Web Component Config
- Web Dev Dependencies
- Web TypeScript Config
- qr_label_screen.dart
- Draft Accept Tests
- Notification Resilience Tests
- Analytics Tests
- Mobile Price Input
- Customer Tests
- Order Serializers
- Edit Business Scope Tests
- Postgres Row Lock Tests
- Web Summary Page
- Mobile Perf Integration Test
- Agent Item QR Tests
- Web Test Suite
- Mobile Agent Detail Tests
- Mobile Scan Beep
- Transport
- Draft Reject Tests
- Mobile Perf Utils
- Mobile Display Order Utils
- Item Multipart Tests
- Web Root Layout
- QRPageContent.tsx
- Web NPM Scripts
- Verify PIN Tests
- OrderEditFlowTests
- Mobile Text Symbols
- Mobile Item Edit Route
- widgets_smoke_test.dart
- VariantRow.tsx
- submitItem.ts
- package:flutter/material.dart
- Mobile Profile Screen
- colorList.tsx
- Draft Retrieve Tests
- Mobile App Config
- return
- Key Features
- stock_validators.dart
- Route /admin/users
- Stock Flow Mobile (Android Admin App)
- ItemSyncService
- Web Auth Middleware
- Mobile Profile Route
- Android MainActivity
- Web Edit Mode Banner
- Web Size Constants
- Mobile Summary Route
- frontend/AGENTS.md
- _DashboardScreenState
- Web PostCSS Config
- qr_label_test.dart
- Mobile Navigation Utils
- SimpleBrandSerializer
- Mobile Summary Screen
- Architecture Concept Link
- Yaak Password Request
- Django Project Package
- frontend/README.md
- stock_flow_admin
- AGENTS.md

## God Nodes (most connected - your core abstractions)
1. `react` - 112 edges
2. `get_auth_header()` - 108 edges
3. `lucide-react` - 97 edges
4. `cn()` - 81 edges
5. `Order` - 74 edges
6. `next` - 72 edges
7. `PageLoading()` - 71 edges
8. `StockFlowButton()` - 63 edges
9. `toastError()` - 63 edges
10. `Agent` - 58 edges

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

## Communities (182 total, 61 thin omitted)

### Community 0 - "Orders API & Lifecycle"
Cohesion: 0.04
Nodes (49): GET /orders/9/invoice (Invoive), POST /orders/1/add-item/ (Add Item), DELETE /orders/16/ (Delete order), POST /orders/ (Register orders), GET /orders/ (Show All orders), PATCH /orders/2/ (Partial Update), GET /orders/1 (Show 1 orders), IsAgent (+41 more)

### Community 1 - "Database Migrations"
Cohesion: 0.02
Nodes (57): Migration, Migration, Migration, Migration, Migration, Migration, Migration, Migration (+49 more)

### Community 2 - "Mobile Models & Domain Helpers"
Cohesion: 0.02
Nodes (110): access, action, address, agentName, asInt, assignedItems, available, avgDispatchHours (+102 more)

### Community 3 - "Web UI Component Props"
Cohesion: 0.12
Nodes (60): Step1CommonDetails(), BrandDetailPage(), NewBrandPage(), EditTransportPage(), NewTransportPage(), AdminDetailPage(), getColorFromId(), NewAdminPage() (+52 more)

### Community 4 - "Mobile Shared Widgets"
Cohesion: 0.02
Nodes (93): connectivityProvider, AdminProfileButton, action, appImageDecodeSide, AppToast, _avatarPalette, borderColor, borderRadius (+85 more)

### Community 5 - "Mobile Dashboard Screens"
Cohesion: 0.02
Nodes (99): _acceptDraft, _actingDrafts, activeCount, AdminTab, _agentDropdown, _agentFilter, _agents, _bannerDismissed (+91 more)

### Community 6 - "Mobile Order & Item Cards"
Cohesion: 0.02
Nodes (95): _FilterToggleChip, _OrderCardView, PageArrowButton, _PaginationBar, _UnreadFilterChip, CartListChildren, _ItemCardView, _ItemsSearchField (+87 more)

### Community 7 - "ItemVariantSize"
Cohesion: 0.05
Nodes (18): ItemCategory, Meta, ItemVariantSize, Meta, CreateItemSerializer, ItemCategorySerializer, Meta, ItemVariantRequestSerializer (+10 more)

### Community 8 - "types/item.ts"
Cohesion: 0.10
Nodes (25): Props, SizeRangeResponse, parseErrorMessage(), CustomerRequirementCustomer, CustomerRequirementItem, CustomerRequirementResponse, EditableVariant, EditCommonDetails (+17 more)

### Community 9 - "Mobile Repository Layer"
Cohesion: 0.02
Nodes (83): acceptDraft, active, addItem, agent, AgentRepo, allVariants, analytics, archived (+75 more)

### Community 10 - "Item"
Cohesion: 0.07
Nodes (28): PUT /items/2/ (Update 1 order), GET /items/size-ranges/ (Size Range), DELETE /items/1/ (Delete Item), POST /items/ (Register Items), PATCH /items/2/ (Partial Update), PUT /items/2/ (Update 1 item), GET /items/by-qr/ (Fetch With QR), GET /items/ (Show All Items) (+20 more)

### Community 11 - "Agent"
Cohesion: 0.06
Nodes (23): Command, Agent, AgentDeleteInfoTests, AgentItemAssignNotifyResilienceTests, BrandAdmin, Command, Brand, Customer (+15 more)

### Community 12 - "items/views.py"
Cohesion: 0.04
Nodes (25): admin_business(), check_admin_pin(), IsAdminOrSelfAgent, IsSuperuser, AgentItem, Meta, AgentItemListSerializer, AgentItemSerializer (+17 more)

### Community 13 - "Web Domain Types"
Cohesion: 0.08
Nodes (46): CustomersPage(), Tab, AgentCustomersPage(), AdminsList(), AgentsList(), CustomerList(), CacheMeta, clearCache() (+38 more)

### Community 14 - "admin/order/status/[id]/page.tsx"
Cohesion: 0.08
Nodes (33): Page(), SettingsPage(), Tab, Page(), OrderDetailHeader(), OrderDetailHeaderProps, BrandsList(), TransportsList() (+25 more)

### Community 15 - "Mobile Order Creation"
Cohesion: 0.03
Nodes (66): _goBack, _messageScaffold, _addItem, build, _cardDecoration, _confirmMerge, createState, _customer (+58 more)

### Community 16 - "Mobile Agent Management"
Cohesion: 0.03
Nodes (62): _agent, agentId, agentName, _agents, _allVariants, _AssignTab, _avatarSection, build (+54 more)

### Community 17 - "Mobile Inventory & Sync"
Cohesion: 0.03
Nodes (60): active, build, children, _clearFilters, createState, disabled, dispose, _done (+52 more)

### Community 18 - "User"
Cohesion: 0.05
Nodes (29): GET /admins/ (Show All Admins), PUT /agents/1/ (Update 1 Agent), POST /admins/ (Register Admin), GET /customers/ (Show All Customers), GET /agents/profile/2, GET /admins/1 (Show 1 Admin), GET /agents/ (Get All Agents), PATCH /customers/2/ (Partial Update) (+21 more)

### Community 19 - "Mobile Analytics Screen"
Cohesion: 0.04
Nodes (49): _applyCustom, _applyPreset, _body, build, _card, centered, createState, _customFrom (+41 more)

### Community 20 - "Mobile Screen Controllers"
Cohesion: 0.05
Nodes (50): AnalyticsScreen, _AnalyticsScreenState, LoginScreen, _LoginScreenState, ItemWizardScreen, _ItemWizardScreenState, ItemsScreen, _ItemsScreenState (+42 more)

### Community 21 - "Mobile Stock Summary"
Cohesion: 0.03
Nodes (57): _breakdownRow, cmp, _compareNumeric, ComputedSummary, computeSummary, _content, createState, dispose (+49 more)

### Community 22 - "customer_new_screen.dart"
Cohesion: 0.08
Nodes (23): _addressCtrl, _agent, _agents, _contactCtrl, _contactRegex, createState, dispose, _fieldDecoration (+15 more)

### Community 23 - "Web Agent Order Types"
Cohesion: 0.08
Nodes (41): AdminHomePage(), AdminHomePageContent(), SimpleAgent, Tab, OrderCard(), OrderCardProps, statusConfig, EMPTY_LABELS (+33 more)

### Community 24 - "Mobile Bulk Import"
Cohesion: 0.04
Nodes (46): _addRow, _BackendError, _backendErrors, _badge, BulkImportScreen, _BulkImportScreenState, _cellText, _clearAll (+38 more)

### Community 25 - "Mobile Item Creation Wizard"
Cohesion: 0.04
Nodes (50): _backFromForm, _blankVariant, build, _categories, _categoriesLoading, _category, _categoryField, _ColorCardTile (+42 more)

### Community 26 - "Mobile Item Editing"
Cohesion: 0.04
Nodes (46): _avatarBlock, backendId, build, _buildGroups, capitalized, _categories, _category, createState (+38 more)

### Community 27 - "Mobile App Shell & Auth UI"
Cohesion: 0.08
Nodes (23): AuthAlert, AuthBranding, AuthCard, AuthSubmitButton, autofocus, build, children, controller (+15 more)

### Community 28 - "Mobile Test Fixtures"
Cohesion: 0.04
Nodes (43): agentDetailJson, agentJson, analyticsJson, asSyncItem, binding, customerJson, customerRequirementsJson, dioAdapter (+35 more)

### Community 29 - "next"
Cohesion: 0.11
Nodes (19): History(), Home(), Profile(), EditOrderScannerPage(), OrderDetailsPage(), OrderScannerPage(), NewOrder(), LeaderboardItem (+11 more)

### Community 30 - "Web User API Types"
Cohesion: 0.12
Nodes (23): Profile(), MyItemsPage(), normalizeAgentItem(), ActionRow(), EmptyState(), InfoRow(), ProfilePage(), SectionHeader() (+15 more)

### Community 31 - "Mobile Size & Piece Math"
Cohesion: 0.04
Nodes (43): kGentsSizes, kKidsSizes, kSizeRangePieceCount, kSizeRangeToSizes, null, pieceCountFor, singleSizeRangeFor, build (+35 more)

### Community 32 - "Web Items UI"
Cohesion: 0.11
Nodes (32): ItemsPage(), getItemImage(), hasOutOfStockVariants(), ItemCard(), ItemCardProps, filterItems(), ItemList(), ItemListProps (+24 more)

### Community 33 - "qr_print_select_screen.dart"
Cohesion: 0.10
Nodes (18): _buildPdf, bytes, _category, createState, _error, _fabric, hasItem, initState (+10 more)

### Community 34 - "Mobile Order Item Selection"
Cohesion: 0.05
Nodes (41): _autoSelectSizeGroup, _availableStock, _back, build, byType, _content, createState, customerId (+33 more)

### Community 35 - "Mobile Customer Detail"
Cohesion: 0.06
Nodes (31): _addressCtrl, _agent, _agents, _avatar, build, _colorFromId, _contactCtrl, createState (+23 more)

### Community 36 - "Mobile Item Sync Store"
Cohesion: 0.05
Nodes (30): adoptServerTime, applyStockRow, applyStockRows, archiveAfterDays, archiveCutoff, _box, check, clearStore (+22 more)

### Community 37 - "ImagePreview.tsx"
Cohesion: 0.05
Nodes (61): AdminAnalyticsPage(), AgentHorizontalBarChart(), AgentHorizontalBarChartProps, CustomerBarChart(), CustomerBarChartProps, ItemBarChart(), ItemBarChartProps, KpiTilesProps (+53 more)

### Community 38 - "Mobile Hive Cache"
Cohesion: 0.05
Nodes (34): AppCache, cacheBox, cacheBoxName, _cacheLog, clearAll, clearItemSync, clearSession, _evictOldest (+26 more)

### Community 39 - "Mobile QR Label PDF"
Cohesion: 0.06
Nodes (31): _buildPrintAllPage, buildQrLabelsPdf, _buildSinglePage, byteData, canvas, caption, category, displayOrder (+23 more)

### Community 40 - "Mobile Profile & Archives"
Cohesion: 0.05
Nodes (34): _Action, _actionCard, _actionRow, _addCategory, _archivedItems, _archivedOrderRow, _archivedOrders, _archivesLoading (+26 more)

### Community 41 - "Mobile Order QR Scanner"
Cohesion: 0.10
Nodes (21): _applyQuery, _backToOrder, _body, build, createState, customerId, _entries, _error (+13 more)

### Community 42 - "Web Build Config"
Cohesion: 0.06
Nodes (33): eslintConfig, engines, node, name, packageManager, private, version, config (+25 more)

### Community 43 - "Authentication API"
Cohesion: 0.12
Nodes (16): POST /auth/login/ (Login), PasswordResetToken, Meta, LoginRequestSerializer, LoginResponseSerializer, UserCreateSerializer, Meta, UserSerializer (+8 more)

### Community 44 - "Order Edit Tests"
Cohesion: 0.11
Nodes (5): AdminNonDraftActionTests, AdminPerformCreateTests, get_auth_header(), PatchGuardTests, UnpackedOrderItemsSuccessTests

### Community 45 - "Django App Registry"
Cohesion: 0.06
Nodes (10): AccountsConfig, AdminsConfig, AgentsConfig, BusinessConfig, CustomersConfig, DashboardConfig, ItemsConfig, NotificationConfig (+2 more)

### Community 46 - "package:go_router/go_router.dart"
Cohesion: 0.03
Nodes (57): build, createState, dispose, _email, _error, ForgotScreen, _ForgotScreenState, _loading (+49 more)

### Community 47 - "Mobile Customer Selection"
Cohesion: 0.04
Nodes (40): _body, build, createState, _creating, _customers, _customerTile, _debounce, dispose (+32 more)

### Community 48 - "QR Label Fit Test"
Cohesion: 0.11
Nodes (16): a, concat, _contentStreams, _draw, _Drawn, kinds, _longName, main (+8 more)

### Community 49 - "Mobile Formatters"
Cohesion: 0.09
Nodes (18): activeFilterCount, _apiDate, archiveCountdownLabel, count, date, _displayDate, formatDate, formatDateShort (+10 more)

### Community 50 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.12
Nodes (9): StockFlowButton, main, main, container, main, pumpWizard, step1Field, typeInto (+1 more)

### Community 51 - "Mobile Unit Tests"
Cohesion: 0.11
Nodes (6): main, main, line, main, order, main

### Community 52 - "Mobile Domain Models"
Cohesion: 0.06
Nodes (30): Agent, AgentItemVariant, AgentUser, AnalyticsData, AnalyticsKpis, AssignedItem, AssignedVariantSize, AuthUser (+22 more)

### Community 53 - "analytics_trend_test.dart"
Cohesion: 0.14
Nodes (8): _analyticsPayload, container, _kpiTiles, main, _analyticsPayload, container, main, trendPaintFinder

### Community 54 - "Draft Order Tests"
Cohesion: 0.10
Nodes (5): AdminAbandonedDraftListTests, AdminDraftVisibilityTests, DraftOwnershipTests, DraftSweepTests, OrderIdsCountTests

### Community 55 - "Mobile Item Sync Service"
Cohesion: 0.06
Nodes (24): attach, _attached, _bootstrap, _delta, detach, didChangeAppLifecycleState, _handleFailure, _inFlight (+16 more)

### Community 56 - "Web Product Order UI"
Cohesion: 0.14
Nodes (24): EditProductDetailPage(), ProductHeader(), ProductHeaderProps, ProductImage(), ProductImageProps, ProductInfo(), ProductInfoProps, QuantitySelector() (+16 more)

### Community 57 - "Mobile Ordered Items"
Cohesion: 0.04
Nodes (42): indexed, isOrderItemFullyPacked, sortOrderItemsUnpackedFirst, totalPieces, createState, customer, customerCount, customerName (+34 more)

### Community 58 - "Web Dependencies Manifest"
Cohesion: 0.07
Nodes (30): dependencies, axios, class-variance-authority, clsx, date-fns, heic2any, js-cookie, lucide-react (+22 more)

### Community 59 - "Push Notification Backend"
Cohesion: 0.09
Nodes (11): DeviceToken, PushSubscription, _get_fcm_app(), send_fcm_to_user(), send_push_to_user(), admin_user_ids(), queue_safely(), RegisterDeviceTokenView (+3 more)

### Community 60 - "Mobile Order Edit Tests"
Cohesion: 0.08
Nodes (15): ApiException, item, main, sizeRow, variant, main, container, editCartMarker (+7 more)

### Community 61 - "Mobile Push Notifications"
Cohesion: 0.07
Nodes (20): _available, init, _initialized, instance, itemId, _local, message, notification (+12 more)

### Community 62 - "Item Purge & Cleanup"
Cohesion: 0.07
Nodes (10): Command, Command, ArchivedItemRecord, purge_archived_items(), purge_threshold(), PurgeResult, cleanup_orphaned_media_task(), purge_archived_items_task() (+2 more)

### Community 64 - "Web Layouts & Navigation"
Cohesion: 0.10
Nodes (30): AdminNewOrderLayout(), AdminLayout(), NoLayout(), MainLayout(), OrderLayout(), AdminNavBar(), AdminProfileButton(), AgentProfileButton() (+22 more)

### Community 65 - "Mobile Dio API Client"
Cohesion: 0.08
Nodes (19): ApiClient, data, dio, _extractMessage, hasToken, init, isNetwork, kPerfStartKey (+11 more)

### Community 66 - "Web Item Assignment PDF"
Cohesion: 0.21
Nodes (13): AssignedItemsPDF(), AssignedItemsPDFProps, PDFVariant, styles, totalStock(), variantPieces(), ItemAssignment(), ItemAssignmentProps (+5 more)

### Community 67 - "Mobile Theme"
Cohesion: 0.08
Nodes (23): AppColors, AppTheme, border, cardBorder, dispatched, dispatchedBg, dispatchedFg, grayBg (+15 more)

### Community 68 - "Mobile Dashboard Tests"
Cohesion: 0.08
Nodes (19): build, StockFlowApp, routerProvider, customerName, draftOrderJson, draftsBody, expiresIn, main (+11 more)

### Community 70 - "react"
Cohesion: 0.07
Nodes (54): ForgotPassword(), Status, classifyError(), ERROR_MESSAGES, ErrorType, Login(), ResetPasswordForm(), ResetPasswordPage() (+46 more)

### Community 71 - "Mobile Summary Tests"
Cohesion: 0.08
Nodes (19): _allRenderedTexts, _expectNoMojibake, main, markers, out, container, lastEditLocation, main (+11 more)

### Community 72 - "Mobile Username & Packing Utils"
Cohesion: 0.15
Nodes (12): container, _dy, _itemBJson, _itemEntryA, _itemEntryB, main, order, _packedOrderJson (+4 more)

### Community 73 - "Mobile Bootstrap & Providers"
Cohesion: 0.09
Nodes (14): container, init, Session, build, conn, _current, isOnline, login (+6 more)

### Community 74 - "get_auth_header"
Cohesion: 0.10
Nodes (6): AdminDraftItemLookupTests, CustomerRequirementsIsolationTests, CustomerRequirementsSuccessTests, get_auth_header(), ItemSyncAPITests, _make_order_item()

### Community 75 - "Mobile Order Flow Utils"
Cohesion: 0.09
Nodes (19): availableSizeRanges, availableStockForSizeGroup, clear, computeDuplicateGroups, customerId, groups, itemName, map (+11 more)

### Community 76 - "Mobile Shared Dialogs"
Cohesion: 0.13
Nodes (20): PasswordField, _PasswordFieldState, _CustomerPickerSheet, _CustomerPickerSheetState, _DraftCardView, _DraftCardViewState, _SearchField, _SearchFieldState (+12 more)

### Community 77 - "lucide-react"
Cohesion: 0.09
Nodes (31): DisplayOrderField(), DisplayOrderFieldProps, EditVariantRow(), ItemEditPage(), blankVariant(), uid(), Step2AddColor(), ASPECTS (+23 more)

### Community 78 - "agent_new_screen.dart"
Cohesion: 0.08
Nodes (19): _contactCtrl, createState, dispose, _emailCtrl, _emailRegex, _existingUsernames, _fieldDecoration, _form (+11 more)

### Community 79 - "PageLoading"
Cohesion: 0.06
Nodes (53): CustomerRequirementsPage(), AdminNewOrderPage(), EditOrderPage(), EditOrderPage(), LoadError, InvoicePage(), urlToDataUrl(), DeleteConfirmDialog() (+45 more)

### Community 80 - "variant_image_source_test.dart"
Cohesion: 0.10
Nodes (12): container, main, pumpEditScreen, container, _imagePickerChannel, main, _mockImagePicker, openChooserFromVariantEditor (+4 more)

### Community 81 - "Web Image Utilities"
Cohesion: 0.19
Nodes (15): getCroppedFile(), getFitFile(), hasTransparency(), loadImage(), shrinkCanvas(), toFile(), computeShrinkSize(), JPEG_QUALITY (+7 more)

### Community 82 - "ordered_items_test.dart"
Cohesion: 0.10
Nodes (16): base, container, itemWithImageJson, main, openPreview, pumpItems, stockEntryWithVariantImageJson, container (+8 more)

### Community 83 - "FCM Token Tests"
Cohesion: 0.10
Nodes (4): DeviceTokenEndpointTests, get_auth_header(), NotifyDispatchTests, SendFcmTaskTests

### Community 84 - "Web Bulk Import"
Cohesion: 0.15
Nodes (17): BackendError, BulkImportPage(), ColumnDef, COLUMNS, CustomerRow, EditableCell(), emptyRow(), ErrorMap (+9 more)

### Community 85 - "Web Component Config"
Cohesion: 0.11
Nodes (18): aliases, components, hooks, lib, ui, utils, iconLibrary, registries (+10 more)

### Community 86 - "Web Dev Dependencies"
Cohesion: 0.11
Nodes (19): devDependencies, eslint, eslint-config-next, jsdom, openapi-typescript, tailwindcss, @tailwindcss/postcss, @testing-library/dom (+11 more)

### Community 87 - "Web TypeScript Config"
Cohesion: 0.11
Nodes (18): compilerOptions, allowJs, esModuleInterop, incremental, isolatedModules, jsx, lib, module (+10 more)

### Community 88 - "qr_label_screen.dart"
Cohesion: 0.11
Nodes (16): QrLabel, _buildPdf, _category, createState, _error, _fabric, initState, _itemName (+8 more)

### Community 92 - "Mobile Price Input"
Cohesion: 0.12
Nodes (14): decDigits, formatEditUpdate, hasDot, intDigits, kMaxItemPrice, kMaxPriceDecimalDigits, kMaxPriceIntegerDigits, out (+6 more)

### Community 93 - "Customer Tests"
Cohesion: 0.21
Nodes (3): CustomerCreateNotifyTests, CustomerListAdminTests, get_auth_header()

### Community 94 - "Order Serializers"
Cohesion: 0.14
Nodes (4): OrderItemSerializer, Meta, OrderSerializer, Meta

### Community 97 - "Web Summary Page"
Cohesion: 0.21
Nodes (14): ComputedSummary, computeSummary(), formatCurrency(), getPieceCount(), getSortName(), ItemSummary, normalizeAdminItem(), SINGLE_SIZE_PIECE_COUNT (+6 more)

### Community 98 - "Mobile Perf Integration Test"
Cohesion: 0.13
Nodes (11): _busyCount, deadline, main, navLabel, pump, _pumpUntil, sw, _tabTtc (+3 more)

### Community 101 - "Mobile Agent Detail Tests"
Cohesion: 0.14
Nodes (11): agent, agentWithAssignedItems, allVariants, assignedCount, container, main, mockAgentDetail, _name (+3 more)

### Community 102 - "Mobile Scan Beep"
Cohesion: 0.29
Nodes (4): _beepPlayer, _playBeep, playConfirmBeep, playScanBeep

### Community 103 - "Transport"
Cohesion: 0.19
Nodes (6): TransportAdmin, Transport, TransportSerializer, Meta, IsAdminUser, TransportViewSet

### Community 105 - "Mobile Perf Utils"
Cohesion: 0.17
Nodes (7): enabled, end, log, Perf, _releaseEnabled, start, _sw

### Community 106 - "Mobile Display Order Utils"
Cohesion: 0.17
Nodes (11): colorNumberLabel, compareItemNamesAsc, compareItemNamesDesc, n, _numRegex, parsed, ta, tb (+3 more)

### Community 107 - "Item Multipart Tests"
Cohesion: 0.18
Nodes (3): ItemCreateMultipartAPITests, ManualDeleteRegressionTests, OrderSnapshotAfterPurgeAPITests

### Community 108 - "Web Root Layout"
Cohesion: 0.24
Nodes (8): jakartha, metadata, RootLayout(), viewport, ServiceWorkerRegister(), AuthProvider(), initializeAuth(), sonner

### Community 109 - "QRPageContent.tsx"
Cohesion: 0.18
Nodes (12): QRPrintPage(), Item, QRLabelPdf(), QRLabelPdfProps, styles, Variant, QRPrintItem, QRPrintPageContent() (+4 more)

### Community 110 - "Web NPM Scripts"
Cohesion: 0.20
Nodes (10): scripts, build, dev, lint, local, mobile, start, test (+2 more)

### Community 111 - "Verify PIN Tests"
Cohesion: 0.36
Nodes (3): get_auth_header(), make_admin(), VerifyPinTests

### Community 113 - "Mobile Text Symbols"
Cohesion: 0.22
Nodes (8): kArrow, kBullet, kEllipsis, kEmDash, kEnDash, kMiddleDot, kMultiply, kRupee

### Community 114 - "Mobile Item Edit Route"
Cohesion: 0.22
Nodes (8): _confirmDeletePin, _editHeader, _save, _commonStep, _submit, build, build, build

### Community 115 - "widgets_smoke_test.dart"
Cohesion: 0.13
Nodes (4): container, main, _mockDashboard, settle

### Community 116 - "VariantRow.tsx"
Cohesion: 0.19
Nodes (13): StockBadge(), StockBadgeProps, deriveSizeGroups(), VariantRow(), VariantRowProps, OrderItemEditModal(), OrderItemEditModalProps, getAvailableStockForSizeGroup() (+5 more)

### Community 117 - "submitItem.ts"
Cohesion: 0.18
Nodes (8): clearFormDataContentType(), itemToFormData(), objectToFormData(), appendFormData(), ApiError, submitItem(), @testing-library/react, vitest

### Community 118 - "package:flutter/material.dart"
Cohesion: 0.11
Nodes (12): from, OrderStatus, statusBadgeColors, statusBarColor, unknown, _item, main, name (+4 more)

### Community 119 - "Mobile Profile Screen"
Cohesion: 0.13
Nodes (12): routeObserver, _login, _handleDelete, ItemEditScreen, _ItemEditScreenState, initState, build, _handleLogout (+4 more)

### Community 120 - "colorList.tsx"
Cohesion: 0.29
Nodes (10): Props, ColorCard(), Props, ColorListScreen(), Props, Props, CommonDetailsBadge(), Props (+2 more)

### Community 122 - "Mobile App Config"
Cohesion: 0.33
Nodes (4): AppConfig, baseUrl, mediaDomain, resolveImageUrl

### Community 123 - "return"
Cohesion: 0.18
Nodes (7): base, counter, deriveUsername, username, count, status, unpackedLineCount

### Community 124 - "Key Features"
Cohesion: 0.18
Nodes (10): Access Control, Admin Dashboard, Inventory Management, Key Features, Order Management, Sales Agent Tools, Stock Flow, Tech Stack (+2 more)

### Community 125 - "stock_validators.dart"
Cohesion: 0.20
Nodes (8): every, itemOutOfStock, itemPartiallyOutOfStock, out, ranges, result, sizeMap, variantOutOfStock

### Community 126 - "Route /admin/users"
Cohesion: 0.20
Nodes (9): _body, _deleteAgent, _saveDetails, build, _body, _delete, _save, build (+1 more)

### Community 127 - "Stock Flow Mobile (Android Admin App)"
Cohesion: 0.25
Nodes (7): 1. Scaffold the Android platform, 2. Android manifest tweaks, 3. Dependencies, 4. Run / build, 5. Verify, Notes / known parity gaps, Stock Flow Mobile (Android Admin App)

### Community 129 - "ItemSyncService"
Cohesion: 0.40
Nodes (4): Delta Sync with Checksum Reconcile, ItemStore, ItemSyncData, ItemSyncService

### Community 130 - "Web Auth Middleware"
Cohesion: 0.67
Nodes (3): config, isTokenExpired(), proxy()

### Community 131 - "Mobile Profile Route"
Cohesion: 0.50
Nodes (3): build, build, build

### Community 136 - "frontend/AGENTS.md"
Cohesion: 0.40
Nodes (3): Architecture, Commands, Conventions

### Community 137 - "_DashboardScreenState"
Cohesion: 0.40
Nodes (4): DashboardScreen, _DashboardScreenState, PulsingDot, _PulsingDotState

## Knowledge Gaps
- **1756 isolated node(s):** `stock_flow_backend`, `date-fns`, `react-dom`, `sharp`, `web-push` (+1751 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2566 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **61 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Order` connect `Web Agent Order Types` to `Architecture Concept Link`, `Authentication API`, `Web User API Types`, `PageLoading`?**
  _High betweenness centrality (0.360) - this node is a cross-community bridge._
- **Are the 58 inferred relationships involving `Order` (e.g. with `GET /orders/9/invoice (Invoive)` and `POST /orders/1/add-item/ (Add Item)`) actually correct?**
  _`Order` has 58 INFERRED edges - model-reasoned connections that need verification._
- **What connects `stock_flow_backend`, `date-fns`, `react-dom` to the rest of the system?**
  _1756 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Orders API & Lifecycle` be split into smaller, more focused modules?**
  _Cohesion score 0.040987424312994875 - nodes in this community are weakly interconnected._
- **Why does `Stock Flow Three-Tier Architecture` connect `Architecture Concept Link` to `Orders API & Lifecycle`, `Web Agent Order Types`?**
  _High betweenness centrality (0.250) - this node is a cross-community bridge._
- **Should `Database Migrations` be split into smaller, more focused modules?**
  _Cohesion score 0.020591085271317828 - nodes in this community are weakly interconnected._
- **Why does `Order` connect `Architecture Concept Link` to `Mobile Models & Domain Helpers`, `Authentication API`, `Mobile Domain Models`?**
  _High betweenness centrality (0.237) - this node is a cross-community bridge._