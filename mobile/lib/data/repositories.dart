import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/cache/app_cache.dart';
import '../features/items/item_sync_service.dart';
import '../models/models.dart';

/// Converts raw JSON lists into typed models.
List<T> _fromList<T>(dynamic data, T Function(Map<String, dynamic>) map) =>
    asList(data, (e) => map((e as Map).cast<String, dynamic>()));

List<int> _ints(dynamic data) {
  if (data is! List) return <int>[];
  return data.map((e) => e is num ? e.toInt() : int.parse(e.toString())).toList();
}

Map<String, dynamic> _asMap(dynamic data) =>
    (data as Map).cast<String, dynamic>();

/// API repositories mirroring `frontend/lib/api/*`.
///
/// Read paths are wrapped with the offline-aware cache (see [AppCache]);
/// every write invalidates the affected cache namespaces.
final class Repositories {
  Repositories({
    AuthRepo? auth,
    OrderRepo? order,
    ItemRepo? item,
    CustomerRepo? customer,
    AgentRepo? agent,
    TransportRepo? transport,
    DashboardRepo? dashboard,
  })  : auth = auth ?? AuthRepo(),
        order = order ?? OrderRepo(),
        item = item ?? ItemRepo(),
        customer = customer ?? CustomerRepo(),
        agent = agent ?? AgentRepo(),
        transport = transport ?? TransportRepo(),
        dashboard = dashboard ?? DashboardRepo();

  final AuthRepo auth;
  final OrderRepo order;
  final ItemRepo item;
  final CustomerRepo customer;
  final AgentRepo agent;
  final TransportRepo transport;
  final DashboardRepo dashboard;
}

final Repositories repos = Repositories();

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

class AuthRepo {
  /// Mirrors `authApi.login`. Accepts email or username; only ADMIN sessions
  /// are allowed into this app.
  Future<Session> login(String login, String password) async {
    try {
      final res = await ApiClient.dio.post<Map<String, dynamic>>(
        '/api/auth/login/',
        data: {'email': login, 'username': login, 'password': password},
      );
      final data = res.data ?? const <String, dynamic>{};
      final role = data['role']?.toString().toUpperCase() ?? '';
      if (role != 'ADMIN') {
        throw ApiException('Only admin accounts can use this app.');
      }
      final user = AuthUser(
        id: (data['user_id'] as num?)?.toInt() ?? 0,
        role: role,
        username: data['username'] as String?,
        email: data['email'] as String?,
        business: data['business'] as String?,
        isSuperuser: data['is_superuser'] == true,
      );
      return Session(
        access: (data['access'] ?? '').toString(),
        refresh: (data['refresh'] ?? '').toString(),
        user: user,
      );
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<AuthUser> profile() async {
    try {
      final res = await ApiClient.dio.get<Map<String, dynamic>>('/api/auth/profile/');
      return AuthUser.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await ApiClient.dio.post('/api/auth/forgot-password/', data: {'email': email});
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<void> resetPassword(String token, String password) async {
    try {
      await ApiClient.dio.post(
        '/api/auth/reset-password/',
        data: {'token': token, 'password': password},
      );
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// Verifies the admin PIN via `/api/auth/verify-pin/` (same PIN used for
  /// destructive actions) without deleting anything.
  Future<void> verifyPin(String pin) async {
    try {
      await ApiClient.dio.post('/api/auth/verify-pin/', data: {'pin': pin});
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }
}

// ---------------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------------

class OrderFilters {
  const OrderFilters({
    this.page = 1,
    this.pageSize = 50,
    this.search,
    this.fromDate,
    this.toDate,
    this.agent,
    this.customer,
    this.statuses = const [],
  });

  final int page;
  final int pageSize;
  final String? search;
  final String? fromDate;
  final String? toDate;
  final int? agent;
  final int? customer;
  final List<String> statuses;

  Map<String, dynamic> toQuery() => {
        'page': page,
        'page_size': pageSize,
        if (search != null && search!.isNotEmpty) 'search': search,
        if (fromDate != null && fromDate!.isNotEmpty) 'from_date': fromDate,
        if (toDate != null && toDate!.isNotEmpty) 'to_date': toDate,
        if (agent != null) 'agent': agent,
        if (customer != null) 'customer': customer,
        if (statuses.isNotEmpty) 'status': statuses,
      };

  String cacheKey() => jsonEncode(toQuery());
}

class OrderRepo {
  Future<Paginated<Order>> getAll(OrderFilters filters) async {
    final data = await AppCache.networkFirst(
      'orders',
      filters.cacheKey(),
      () async {
        final res = await ApiClient.dio.get<Map<String, dynamic>>(
          '/api/orders/',
          queryParameters: filters.toQuery(),
        );
        return res.data;
      },
    );
    return Paginated.fromJson(_asMap(data), Order.fromJson);
  }

  Future<Order> getOne(int id) async {
    final data = await AppCache.networkFirst('order', '$id', () async {
      final res = await ApiClient.dio.get<Map<String, dynamic>>('/api/orders/$id/');
      return res.data;
    });
    return Order.fromJson(_asMap(data));
  }

  /// Creates a DRAFT order for a customer. Admins must send the customer's
  /// assigned [agent] — the backend validates it (mirrors `orderApi.create`).
  Future<Order> create({required int customer, required int agent}) async {
    try {
      final res = await ApiClient.dio.post<Map<String, dynamic>>(
        '/api/orders/',
        data: {'customer': customer, 'status': 'DRAFT', 'agent': agent},
      );
      await _invalidateOrders();
      return Order.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// Adds a scanned variant to a DRAFT order (mirrors `orderApi.addItem`).
  Future<void> addItem(
    int orderId, {
    required String qrCode,
    required int quantity,
    required String sizeGroup,
  }) async {
    try {
      await ApiClient.dio.post(
        '/api/orders/$orderId/add-item/',
        data: {
          'qr_code': qrCode,
          'quantity': quantity,
          'size_group': sizeGroup,
        },
      );
      await _invalidateOrders();
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// Places a DRAFT order. Stock is deducted here, so item caches are also
  /// invalidated (mirrors `orderApi.placeOrder`).
  Future<void> place(
    int orderId, {
    String? expectedDeliveryDate,
    int? preferredTransport,
    String? notes,
  }) async {
    try {
      await ApiClient.dio.post(
        '/api/orders/$orderId/place-order/',
        data: {
          'expected_delivery_date': expectedDeliveryDate,
          'preferred_transport': preferredTransport,
          'notes': notes,
        },
      );
      await _invalidateOrders();
      await AppCache.invalidate('items');
      await AppCache.invalidate('item');
      await AppCache.invalidate('summary');
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// Enters edit mode for a PENDING/PACKED order. The backend snapshots the
  /// captured items and sets status=EDITING atomically (mirrors
  /// `orderApi.startEdit`). Item stock stays reserved while editing.
  Future<void> startEdit(int orderId) async {
    try {
      await ApiClient.dio.post('/api/orders/$orderId/start-edit/');
      await _invalidateOrders();
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// Commits an in-progress edit. The backend restores snapshot stock,
  /// re-deducts the final items, and returns the order to its pre-edit status
  /// (mirrors `orderApi.saveEdit`). [expectedDeliveryDate], [preferredTransport]
  /// and [notes] are applied to the order in the same request.
  Future<void> saveEdit(
    int orderId, {
    String? expectedDeliveryDate,
    int? preferredTransport,
    String? notes,
  }) async {
    try {
      await ApiClient.dio.post(
        '/api/orders/$orderId/save-edit/',
        data: {
          'expected_delivery_date': expectedDeliveryDate,
          'preferred_transport': preferredTransport,
          'notes': notes,
        },
      );
      await _invalidateOrders();
      await AppCache.invalidate('items');
      await AppCache.invalidate('item');
      await AppCache.invalidate('summary');
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// Aborts an in-progress edit, restoring the captured snapshot and the
  /// pre-edit status (mirrors `orderApi.cancelEdit`). Safe to call even if no
  /// edit is active — the backend then returns 400 which is treated as a no-op.
  Future<void> cancelEdit(int orderId) async {
    try {
      await ApiClient.dio.post('/api/orders/$orderId/cancel-edit/');
      await _invalidateOrders();
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// Order history for a customer detail page (mirrors `orderApi.getByCustomer`).
  Future<Paginated<Order>> byCustomer(int customerId,
      {int page = 1, int pageSize = 50}) async {
    final query = {'customer': customerId, 'page': page, 'page_size': pageSize};
    final data = await AppCache.networkFirst('orders', jsonEncode(query), () async {
      final res = await ApiClient.dio
          .get<Map<String, dynamic>>('/api/orders/', queryParameters: query);
      return res.data;
    });
    return Paginated.fromJson(_asMap(data), Order.fromJson);
  }

  /// Archived orders (mirrors `orderApi.getArchived`).
  Future<Paginated<Order>> archived({int page = 1, int pageSize = 50}) async {
    final query = {'page': page, 'page_size': pageSize};
    final data = await AppCache.networkFirst('orders', 'archived', () async {
      final res = await ApiClient.dio
          .get<Map<String, dynamic>>('/api/orders/archived/', queryParameters: query);
      return res.data;
    });
    return Paginated.fromJson(_asMap(data), Order.fromJson);
  }

  Future<List<OrderLog>> getLogs(int id) async {
    final data = await AppCache.networkFirst('logs', '$id', () async {
      final res = await ApiClient.dio.get<List<dynamic>>('/api/orders/$id/logs/');
      return res.data;
    });
    return _fromList(data, OrderLog.fromJson);
  }

  Future<List<int>> getViewedIds() async {
    final data = await AppCache.staleWhileRevalidate(
      'orders',
      'viewed',
      () async {
        final res = await ApiClient.dio
            .get<List<dynamic>>('/api/orders/my-viewed-ids/');
        return res.data;
      },
      ttl: const Duration(minutes: 5),
    );
    return _ints(data);
  }

  /// Cheap `{id, status}` snapshot for per-tab unread counts (mirrors
  /// `orderApi.getAllIds()`).
  Future<List<({int id, String status})>> allIds() async {
    final data = await AppCache.staleWhileRevalidate(
      'orders',
      'allIds',
      () async {
        final res =
            await ApiClient.dio.get<List<dynamic>>('/api/orders/order-ids/');
        return res.data;
      },
      ttl: const Duration(minutes: 2),
    );
    return (data as List).map((e) {
      final m = (e as Map).cast<String, dynamic>();
      return (id: asInt(m['id']) ?? 0, status: s(m['status']));
    }).toList();
  }

  Future<void> markViewed(int orderId) async {
    await ApiClient.dio.post('/api/orders/$orderId/mark-viewed/');
    await AppCache.invalidate('orders');
  }

  Future<void> update(int id, Map<String, dynamic> body) async {
    try {
      await ApiClient.dio.patch('/api/orders/$id/', data: body);
      await _invalidateOrders();
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<void> updateItem(int itemId, Map<String, dynamic> body) async {
    try {
      await ApiClient.dio.patch('/api/orders/order-items/$itemId/', data: body);
      await _invalidateOrders();
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<void> deleteItem(int orderId, int itemId) async {
    try {
      await ApiClient.dio
          .delete('/api/orders/$orderId/delete-item/$itemId/');
      await _invalidateOrders();
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<void> dispatch(int id, {int? transportCompany, String? lrNumber}) async {
    try {
      await ApiClient.dio.post(
        '/api/orders/$id/dispatch/',
        data: {'transport_company': transportCompany, 'lr_number': lrNumber},
      );
      await _invalidateOrders();
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<void> delete(int id, String pin) async {
    try {
      await ApiClient.dio.delete('/api/orders/$id/', data: {'pin': pin});
      await _invalidateOrders();
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// Unpacked order items (packing screen warning data).
  Future<List<Map<String, dynamic>>> unpacked() async {
    try {
      final data = await AppCache.networkFirst('unpacked', 'all', () async {
        final res =
            await ApiClient.dio.get<List<dynamic>>('/api/orders/order-items/unpacked/');
        return res.data;
      });
      return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<void> _invalidateOrders() async {
    await AppCache.invalidate('orders');
    await AppCache.invalidate('order');
    await AppCache.invalidate('unpacked');
    await AppCache.invalidate('dash');
    ItemSyncService.instance.trigger(force: true);
  }
}

// ---------------------------------------------------------------------------
// Items
// ---------------------------------------------------------------------------

/// A variant for the item-create multipart body — mirrors the web wizard's
/// `ColorVariant` flattened into per-size stock rows.
class ItemVariantPayload {
  const ItemVariantPayload({
    this.imagePath,
    required this.sizes,
    required this.displayOrder,
  });

  final String? imagePath;
  final List<({String size, int stock})> sizes;
  final String displayOrder;
}

class ItemRepo {
  /// Fetched once and cached for a week — mirrors the SizeRangeContext cache.
  Future<Map<String, dynamic>> sizeRanges() async {
    final data = await AppCache.staleWhileRevalidate(
      'sizeRanges',
      'all',
      () async {
        final res = await ApiClient.dio
            .get<Map<String, dynamic>>('/api/items/size-ranges');
        return res.data;
      },
      ttl: const Duration(days: 7),
    );
    return _asMap(data);
  }

  Future<List<ItemStockEntry>> stockList() async {
    final data = await AppCache.networkFirst('items', 'stock', () async {
      final res =
          await ApiClient.dio.get<List<dynamic>>('/api/items/stock-list/');
      return res.data;
    });
    return _fromList(data, ItemStockEntry.fromJson);
  }

  /// `GET /api/items/archived/` — used by the profile Archives tab.
  Future<List<Item>> archived() async {
    final data = await AppCache.networkFirst('items', 'archived', () async {
      final res =
          await ApiClient.dio.get<List<dynamic>>('/api/items/archived/');
      return res.data;
    });
    return _fromList(data, Item.fromJson);
  }

  Future<Item> getOne(int id) async {
    final data = await AppCache.networkFirst('item', '$id', () async {
      final res = await ApiClient.dio.get<Map<String, dynamic>>('/api/items/$id/');
      return res.data;
    });
    return Item.fromJson(_asMap(data));
  }

  /// `GET /api/items/by-qr/?qr_code=...` — used by the QR label printer.
  Future<Map<String, dynamic>> byqrcode(String qrCode) async {
    final data = await AppCache.networkFirst('items', 'byqr::$qrCode', () async {
      final res = await ApiClient.dio.get<Map<String, dynamic>>(
        '/api/items/by-qr/',
        queryParameters: {'qr_code': qrCode},
      );
      return res.data;
    });
    return _asMap(data);
  }

  /// Live (uncached) by-QR lookup for the order flow. Admins omit [agentId]
  /// so no assignment restriction is applied.
  Future<ItemQR> byQr(String qrCode, {int? agentId}) async {
    try {
      final res = await ApiClient.dio.get<Map<String, dynamic>>(
        '/api/items/by-qr/',
        queryParameters: {
          'qr_code': qrCode,
          if (agentId != null) 'agent_id': agentId,
        },
      );
      return ItemQR.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// Live per-order availability check for a scanned QR.
  Future<CheckStockResult> checkOutOfStock(String qrCode, {int? orderId}) async {
    try {
      final res = await ApiClient.dio.get<Map<String, dynamic>>(
        '/api/items/by-qr/out-of-stock/',
        queryParameters: {
          'qr_code': qrCode,
          if (orderId != null) 'order_id': orderId,
        },
      );
      return CheckStockResult.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// Every variant across all items — used by agent item assignment.
  Future<List<VariantAllItem>> allVariants() async {
    final data = await AppCache.staleWhileRevalidate(
      'items',
      'variants',
      () async {
        final res = await ApiClient.dio
            .get<List<dynamic>>('/api/items/variants/all/');
        return res.data;
      },
      ttl: const Duration(minutes: 15),
    );
    return _fromList(data, VariantAllItem.fromJson);
  }

  Future<Map<String, dynamic>> customerRequirements(int itemId) async {
    try {
      final data = await AppCache.networkFirst('items', 'reqs::$itemId', () async {
        final res = await ApiClient.dio.get<Map<String, dynamic>>(
          '/api/items/customer-requirements/',
          queryParameters: {'item_id': itemId},
        );
        return res.data;
      });
      return _asMap(data);
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// Creates an item (JSON). Returns the parsed item so variant images can be
  /// uploaded afterwards via [patchVariantImage].
  Future<Item> create(Map<String, dynamic> body) async {
    try {
      final res = await ApiClient.dio.post<Map<String, dynamic>>('/api/items/', data: body);
      await _invalidateItems();
      return Item.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// One variant's payload for the item-create multipart body (mirrors
  /// `itemToFormData` in the web app).
  Future<Item> createMultipart({
    required String name,
    required String description,
    required double price,
    required String type,
    required List<ItemVariantPayload> variants,
  }) async {
    try {
      final fd = FormData();
      fd.fields.add(MapEntry('name', name));
      fd.fields.add(MapEntry('description', description));
      fd.fields.add(MapEntry('price', price.toString()));
      fd.fields.add(MapEntry('type', type));
      for (var i = 0; i < variants.length; i++) {
        final v = variants[i];
        if (v.imagePath != null) {
          final fileName = v.imagePath!.split('/').last.split('\\').last;
          fd.files.add(MapEntry(
            'variants[$i]image',
            await MultipartFile.fromFile(v.imagePath!, filename: fileName),
          ));
        }
        fd.fields.add(MapEntry('variants[$i]display_order', v.displayOrder));
        for (var j = 0; j < v.sizes.length; j++) {
          fd.fields.add(MapEntry('variants[$i]sizes[$j]size', v.sizes[j].size));
          fd.fields.add(MapEntry(
              'variants[$i]sizes[$j]stock', v.sizes[j].stock.toString()));
        }
      }
      final res = await ApiClient.dio.post<Map<String, dynamic>>('/api/items/', data: fd);
      await _invalidateItems();
      return Item.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// Deletes an item (superuser/PIN-gated) — mirrors `itemApi.delete(id, pin)`.
  Future<void> deleteWithPin(int id, String pin) async {
    try {
      await ApiClient.dio.delete<void>('/api/items/$id/', data: {'pin': pin});
      await _invalidateItems();
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<Item> update(int id, Map<String, dynamic> body) async {
    try {
      final res =
          await ApiClient.dio.put<Map<String, dynamic>>('/api/items/$id/', data: body);
      await _invalidateItems();
      return Item.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// Multipart image upload for a variant (keeps `/api` prefix parity with the
  /// web's editItem/updateItem helpers).
  Future<void> patchVariantImage(int variantId, String filePath, {String? filename}) async {
    try {
      final name = filename ?? filePath.split('/').last.split('\\').last;
      final form = FormData.fromMap({
        'image': await MultipartFile.fromFile(filePath, filename: name),
      });
      await ApiClient.dio.patch('/api/items/variants/$variantId/', data: form);
      await _invalidateItems();
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<void> delete(int id, String pin) async {
    try {
      await ApiClient.dio.delete('/api/items/$id/', data: {'pin': pin});
      await _invalidateItems();
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<void> _invalidateItems() async {
    await AppCache.invalidate('items');
    await AppCache.invalidate('item');
    await AppCache.invalidate('summary');
    ItemSyncService.instance.trigger(force: true);
  }
}

// ---------------------------------------------------------------------------
// Customers
// ---------------------------------------------------------------------------

class CustomerRepo {
  Future<Paginated<Customer>> list({int page = 1, int pageSize = 50, String? search}) async {
    final query = {'page': page, 'page_size': pageSize, if (search != null && search.isNotEmpty) 'search': search};
    final key = jsonEncode(query);
    final data = await AppCache.staleWhileRevalidate(
      'customers',
      key,
      () async {
        final res = await ApiClient.dio
            .get<Map<String, dynamic>>('/api/customers/', queryParameters: query);
        return res.data;
      },
      ttl: const Duration(minutes: 10),
    );
    return Paginated.fromJson(_asMap(data), Customer.fromJson);
  }

  /// Mirrors `customerApi.bulkImport` — `POST /api/customers/bulk-import/`.
  /// Returns `{created, errors: [{row, name, error}]}`.
  Future<({int created, List<(int row, String name, String error)> errors})>
      bulkImport(List<Map<String, dynamic>> customers) async {
    try {
      final res = await ApiClient.dio.post<Map<String, dynamic>>(
        '/api/customers/bulk-import/',
        data: {'customers': customers},
      );
      await AppCache.invalidate('customers');
      final data = _asMap(res.data);
      final created = asInt(data['created']) ?? 0;
      final errors = <(int, String, String)>[];
      for (final e in asList(data['errors'], _asMap)) {
        errors.add((
          asInt(e['row']) ?? 0,
          s(e['name']),
          s(e['error']),
        ));
      }
      return (created: created, errors: errors);
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<Customer> getOne(int id) async {
    final data = await AppCache.staleWhileRevalidate(
      'customer',
      '$id',
      () async {
        final res = await ApiClient.dio.get<Map<String, dynamic>>('/api/customers/$id/');
        return res.data;
      },
      ttl: const Duration(minutes: 10),
    );
    return Customer.fromJson(_asMap(data));
  }

  Future<Customer> create(Map<String, dynamic> body) async {
    try {
      final res = await ApiClient.dio.post<Map<String, dynamic>>('/api/customers/', data: body);
      await AppCache.invalidate('customers');
      return Customer.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<Customer> update(int id, Map<String, dynamic> body) async {
    try {
      final res = await ApiClient.dio.patch<Map<String, dynamic>>('/api/customers/$id/', data: body);
      await AppCache.invalidate('customers');
      await AppCache.invalidate('customer');
      return Customer.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<Map<String, dynamic>> deleteInfo(int id) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>('/api/customers/$id/delete_info/');
    return _asMap(res.data);
  }

  Future<void> delete(int id, String pin, {String? action}) async {
    try {
      await ApiClient.dio.delete('/api/customers/$id/', data: {'pin': pin, if (action != null) 'action': action});
      await AppCache.invalidate('customers');
      await AppCache.invalidate('customer');
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }
}

// ---------------------------------------------------------------------------
// Agents
// ---------------------------------------------------------------------------

class AgentRepo {
  Future<List<Agent>> list() async {
    final data = await AppCache.staleWhileRevalidate(
      'agents',
      'all',
      () async {
        final res = await ApiClient.dio.get<List<dynamic>>('/api/agents/');
        return res.data;
      },
      ttl: const Duration(minutes: 30),
    );
    return _fromList(data, Agent.fromJson);
  }

  Future<Agent> getOne(int id) async {
    try {
      final data = await AppCache.staleWhileRevalidate(
        'agent',
        '$id',
        () async {
          final res = await ApiClient.dio.get<Map<String, dynamic>>('/api/agents/$id/');
          return res.data;
        },
        ttl: const Duration(minutes: 10),
      );
      return Agent.fromJson(_asMap(data));
    } catch (_) {
      final cachedList = await AppCache.read('agents', 'all');
      if (cachedList is List) {
        for (final e in cachedList) {
          if (e is Map && asInt(e['id']) == id) {
            return Agent.fromJson(_asMap(e));
          }
        }
      }
      rethrow;
    }
  }

  Future<Agent> create(Map<String, dynamic> body) async {
    try {
      final res = await ApiClient.dio.post<Map<String, dynamic>>('/api/agents/', data: body);
      await AppCache.invalidate('agents');
      return Agent.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<Agent> update(int id, Map<String, dynamic> body) async {
    try {
      final res = await ApiClient.dio.patch<Map<String, dynamic>>('/api/agents/$id/', data: body);
      await AppCache.invalidate('agents');
      await AppCache.invalidate('agent');
      return Agent.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<Map<String, dynamic>> deleteInfo(int id) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>('/api/agents/$id/delete_info/');
    return _asMap(res.data);
  }

  Future<void> delete(int id, String pin, {String? action, int? transferToId}) async {
    try {
      await ApiClient.dio.delete('/api/agents/$id/', data: {
        'pin': pin,
        if (action != null) 'action': action,
        if (transferToId != null) 'transfer_to_id': transferToId,
      });
      await AppCache.invalidate('agents');
      await AppCache.invalidate('agent');
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<void> updateItems(int agentId, List<int> variantIds) async {
    try {
      await ApiClient.dio.post(
        '/api/agents/$agentId/items/',
        data: {'variant_ids': variantIds},
      );
      await AppCache.invalidate('agents');
      await AppCache.invalidate('agent');
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<void> transferItems(int agentId, int targetAgentId) async {
    try {
      await ApiClient.dio.post(
        '/api/agents/$agentId/items/transfer/',
        data: {'target_agent_id': targetAgentId},
      );
      await AppCache.invalidate('agents');
      await AppCache.invalidate('agent');
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<void> copyItems(int agentId, int targetAgentId) async {
    try {
      await ApiClient.dio.post(
        '/api/agents/$agentId/items/copy/',
        data: {'target_agent_id': targetAgentId},
      );
      await AppCache.invalidate('agents');
      await AppCache.invalidate('agent');
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  Future<void> deleteAllItems(int agentId) async {
    try {
      await ApiClient.dio.delete('/api/agents/$agentId/items/');
      await AppCache.invalidate('agents');
      await AppCache.invalidate('agent');
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }
}

// ---------------------------------------------------------------------------
// Transports
// ---------------------------------------------------------------------------

class TransportRepo {
  Future<List<Transport>> active() async {
    final data = await AppCache.staleWhileRevalidate(
      'transports',
      'active',
      () async {
        final res = await ApiClient.dio.get<List<dynamic>>('/api/transports/active/');
        return res.data;
      },
      ttl: const Duration(hours: 24),
    );
    return _fromList(data, Transport.fromJson);
  }
}

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

class DashboardRepo {
  Future<AnalyticsData> analytics(String from, String to) async {
    final data = await AppCache.staleWhileRevalidate(
      'dash-v2',
      '$from::$to',
      () async {
        final res = await ApiClient.dio.get<Map<String, dynamic>>(
          '/api/dashboard/analytics/',
          queryParameters: {'from': from, 'to': to},
        );
        return res.data;
      },
      ttl: const Duration(minutes: 15),
    );
    return AnalyticsData.fromJson(_asMap(data));
  }
}