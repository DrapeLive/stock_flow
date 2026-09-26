/// Data models mirroring `frontend/types/*.ts`. Field names follow the Django
/// serializer keys verbatim.
library;

import 'package:flutter/foundation.dart';

int? asInt(dynamic v) => v is num ? v.toInt() : v is String ? int.tryParse(v) : null;

String s(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

List<T> asList<T>(dynamic v, T Function(Map<String, dynamic>) map) =>
    v is List
        ? v.map((e) => map((e as Map).cast<String, dynamic>())).toList()
        : <T>[];

// ---------------------------------------------------------------------------
// Global
// ---------------------------------------------------------------------------

@immutable
class Paginated<T> {
  const Paginated({required this.count, this.next, this.previous, required this.results});
  final int count;
  final String? next;
  final String? previous;
  final List<T> results;

  factory Paginated.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) map) =>
      Paginated(
        count: asInt(json['count']) ?? 0,
        next: json['next'] as String?,
        previous: json['previous'] as String?,
        results: asList(json['results'], map),
      );
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.role,
    this.username,
    this.displayName,
    this.email,
    this.business,
    this.isSuperuser = false,
  });

  final int id;
  final String role;
  final String? username;
  final String? displayName;
  final String? email;
  final String? business;
  final bool isSuperuser;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: asInt(json['id']) ?? 0,
        role: s(json['role']),
        username: json['username'] as String?,
        displayName: json['display_name'] as String?,
        email: json['email'] as String?,
        business: json['business'] as String?,
        isSuperuser: json['is_superuser'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'username': username,
        'display_name': displayName,
        'email': email,
        'business': business,
        'is_superuser': isSuperuser,
      };
}

@immutable
class Session {
  const Session({
    required this.access,
    required this.refresh,
    required this.user,
  });

  final String access;
  final String refresh;
  final AuthUser user;

  Map<String, dynamic> toJson() => {
        'access': access,
        'refresh': refresh,
        'user': {
          'id': user.id,
          'role': user.role,
          'username': user.username,
          'email': user.email,
          'business': user.business,
          'is_superuser': user.isSuperuser,
        },
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        access: s(json['access']),
        refresh: s(json['refresh']),
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

// ---------------------------------------------------------------------------
// Item
// ---------------------------------------------------------------------------

@immutable
class ItemVariantSize {
  const ItemVariantSize({this.id, this.sizeRange, this.size, required this.stock});
  final int? id;
  final String? sizeRange;
  final String? size;
  final int stock;

  factory ItemVariantSize.fromJson(Map<String, dynamic> json) => ItemVariantSize(
        id: asInt(json['id']),
        sizeRange: json['size_range'] as String?,
        size: json['size'] as String?,
        stock: asInt(json['stock']) ?? 0,
      );
}

@immutable
class ItemVariant {
  const ItemVariant({
    required this.id,
    this.qrCode,
    this.image,
    required this.sizes,
    this.displayOrder,
  });

  final int id;
  final String? qrCode;
  final String? image;
  final List<ItemVariantSize> sizes;
  final String? displayOrder;

  factory ItemVariant.fromJson(Map<String, dynamic> json) => ItemVariant(
        id: asInt(json['id']) ?? 0,
        qrCode: json['qr_code'] as String?,
        image: json['image'] as String?,
        sizes: asList(json['sizes'], ItemVariantSize.fromJson),
        displayOrder: json['display_order'] as String?,
      );
}

@immutable
class Item {
  const Item({
    required this.id,
    required this.name,
    this.type,
    required this.price,
    this.description,
    required this.variants,
    this.purgeOn,
    this.daysUntilPurge,
  });

  final int id;
  final String name;
  final String? type;
  final String price;
  final String? description;
  final List<ItemVariant> variants;
  final String? purgeOn;
  final int? daysUntilPurge;

  int get totalStock => variants.fold(
      0, (sum, v) => sum + v.sizes.fold(0, (a, b) => a + b.stock));

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: asInt(json['id']) ?? 0,
        name: s(json['name']),
        type: json['type'] as String?,
        price: s(json['price']),
        description: json['description'] as String?,
        variants: asList(json['variants'], ItemVariant.fromJson),
        purgeOn: json['purge_on'] as String?,
        daysUntilPurge: asInt(json['days_until_purge']),
      );
}

@immutable
class VariantSize {
  const VariantSize({required this.sizeRange, required this.stock});
  final String sizeRange;
  final int stock;

  factory VariantSize.fromJson(Map<String, dynamic> json) => VariantSize(
        sizeRange: s(json['size_range'] ?? json['size']),
        stock: asInt(json['stock']) ?? 0,
      );
}

/// Row of `/api/items/variants/all/` used by agent item assignment.
@immutable
class VariantAllItem {
  const VariantAllItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.itemType,
    required this.itemPrice,
    this.qrCode,
    this.image,
    required this.sizes,
    required this.totalStock,
    required this.uniqueSizes,
  });

  final int id;
  final int itemId;
  final String itemName;
  final String itemType;
  final String itemPrice;
  final String? qrCode;
  final String? image;
  final List<VariantSize> sizes;
  final int totalStock;
  final List<String> uniqueSizes;

  factory VariantAllItem.fromJson(Map<String, dynamic> json) => VariantAllItem(
        id: asInt(json['id']) ?? 0,
        itemId: asInt(json['item_id']) ?? 0,
        itemName: s(json['item_name']),
        itemType: s(json['item_type']),
        itemPrice: s(json['item_price']),
        qrCode: json['qr_code'] as String?,
        image: json['image'] as String?,
        sizes: asList(json['sizes'], VariantSize.fromJson),
        totalStock: asInt(json['total_stock']) ?? 0,
        uniqueSizes: (json['unique_sizes'] as List? ?? const [])
            .map((e) => s(e))
            .toList(),
      );
}

@immutable
class ItemVariantQR {
  const ItemVariantQR({
    required this.id,
    this.qrCode,
    this.image,
    required this.sizes,
    required this.totalStock,
    this.displayOrder,
    this.createdAt,
  });

  final int id;
  final String? qrCode;
  final String? image;
  final List<VariantSize> sizes;
  final int totalStock;
  final String? displayOrder;
  final String? createdAt;

  factory ItemVariantQR.fromJson(Map<String, dynamic> json) => ItemVariantQR(
        id: asInt(json['id']) ?? 0,
        qrCode: json['qr_code'] as String?,
        image: json['image'] as String?,
        sizes: asList(json['sizes'], VariantSize.fromJson),
        totalStock: asInt(json['total_stock']) ?? 0,
        displayOrder: json['display_order'] as String?,
        createdAt: json['created_at'] as String?,
      );
}

/// Row of `/api/items/stock-list/` used by the items screen + summary.
@immutable
class ItemStockEntry {
  const ItemStockEntry({
    required this.id,
    required this.name,
    this.type,
    required this.price,
    this.image,
    required this.variants,
  });

  final int id;
  final String name;
  final String? type;
  final String price;
  final String? image;
  final List<ItemVariantQR> variants;

  int get totalStock =>
      variants.fold(0, (sum, v) => sum + v.sizes.fold(0, (a, b) => a + b.stock));

  int get totalSets =>
      variants.fold(0, (sum, v) => sum + (v.sizes.isNotEmpty ? v.sizes.length : 0));

  factory ItemStockEntry.fromJson(Map<String, dynamic> json) => ItemStockEntry(
        id: asInt(json['id']) ?? 0,
        name: s(json['name']),
        type: json['type'] as String?,
        price: s(json['price']),
        image: json['image'] as String?,
        variants: asList(json['variants'], ItemVariantQR.fromJson),
      );
}

/// Response of `/api/items/by-qr/?qr_code=...` used by the order flow.
@immutable
class ItemQR {
  const ItemQR({
    required this.id,
    required this.name,
    this.type,
    required this.price,
    this.description,
    required this.variants,
    this.matchedVariantId,
  });

  final int id;
  final String name;
  final String? type;
  final String price;
  final String? description;
  final List<ItemVariantQR> variants;
  final int? matchedVariantId;

  factory ItemQR.fromJson(Map<String, dynamic> json) => ItemQR(
        id: asInt(json['id']) ?? 0,
        name: s(json['name']),
        type: json['type'] as String?,
        price: s(json['price']),
        description: json['description'] as String?,
        variants: asList(json['variants'], ItemVariantQR.fromJson),
        matchedVariantId: asInt(json['matched_variant_id']),
      );
}

/// Response of `/api/items/by-qr/out-of-stock/`.
@immutable
class CheckStockResult {
  const CheckStockResult({required this.outOfStock, required this.groupStock});
  final bool outOfStock;
  final Map<String, int> groupStock;

  factory CheckStockResult.fromJson(Map<String, dynamic> json) {
    final raw = json['group_stock'];
    return CheckStockResult(
      outOfStock: json['out_of_stock'] == true,
      groupStock: raw is Map
          ? {
              for (final e in raw.entries)
                e.key.toString(): asInt(e.value) ?? 0,
            }
          : const {},
    );
  }
}

/// One row of place-order's 400 `out_of_stock_items` payload.
@immutable
class OutOfStockItem {
  const OutOfStockItem({
    required this.itemName,
    required this.sizeGroup,
    this.size,
    required this.requiredQty,
    required this.available,
    required this.orderItemId,
  });

  final String itemName;
  final String sizeGroup;
  final String? size;
  final int requiredQty;
  final int available;
  final int orderItemId;

  factory OutOfStockItem.fromJson(Map<String, dynamic> json) => OutOfStockItem(
        itemName: s(json['item_name']),
        sizeGroup: s(json['size_group']),
        size: json['size'] as String?,
        requiredQty: asInt(json['required']) ?? 0,
        available: asInt(json['available']) ?? 0,
        orderItemId: asInt(json['order_item_id']) ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Order
// ---------------------------------------------------------------------------

@immutable
class SimpleAgent {
  const SimpleAgent(
      {required this.id, this.username, this.displayName, this.contact});
  final int id;
  final String? username;
  final String? displayName;
  final String? contact;

  /// Prefers the display name, falling back to the username.
  String get name =>
      (displayName?.isNotEmpty ?? false)
          ? displayName!
          : (username?.isNotEmpty ?? false)
              ? username!
              : 'Agent $id';

  factory SimpleAgent.fromJson(Map<String, dynamic> json) => SimpleAgent(
        id: asInt(json['id']) ?? 0,
        username: json['username'] as String?,
        displayName: json['display_name'] as String?,
        contact: json['contact'] as String?,
      );
}

@immutable
class SimpleCustomer {
  const SimpleCustomer({
    required this.id,
    required this.name,
    this.contact,
    this.address,
    this.gst,
  });
  final int id;
  final String name;
  final String? contact;
  final String? address;
  final String? gst;
  factory SimpleCustomer.fromJson(Map<String, dynamic> json) => SimpleCustomer(
        id: asInt(json['id']) ?? 0,
        name: s(json['name']),
        contact: json['contact'] as String?,
        address: json['address'] as String?,
        gst: json['gst'] as String?,
      );
}

@immutable
class OrderItem {
  const OrderItem({
    required this.id,
    this.item,
    this.variant,
    this.sizeGroup,
    this.size,
    this.itemName,
    this.itemPrice,
    this.variantImage,
    this.quantity = 0,
    this.originalQuantity,
    this.packedQuantity,
    this.pieceCount,
    required this.variantDisplayOrder,
    this.order,
  });

  final int id;
  final Item? item;
  final int? variant;
  final String? sizeGroup;
  final String? size;
  final String? itemName;
  final String? itemPrice;
  final String? variantImage;
  final int quantity;
  final int? originalQuantity;
  final int? packedQuantity;
  final int? pieceCount;
  final int? order;
  final String variantDisplayOrder;

  String get displayName => item?.name ?? itemName ?? 'Item';

  /// For order rows: `Name ( Color #N )` when the variant has a display_order,
  /// otherwise just the name (never `( Color # )`).
  String get displayNameWithColor {
    final order = variantDisplayOrder.trim();
    return order.isEmpty ? displayName : '$displayName ( Color #$order )';
  }
  String get displayPrice => item?.price ?? itemPrice ?? '';
  String? get imageUrl => item?.variants.isEmpty == true ? null : (toVariantImage());
  String? toVariantImage() {
    if (variantImage != null) return variantImage;
    if (item != null && variant != null) {
      for (final v in item!.variants) {
        if (v.id == variant) return v.image;
      }
    }
    return null;
  }
  String? get displaySizeGroup => sizeGroup ??
      (item != null && variant != null
          ? _sizeGroupForItem(item!, variant!)
          : size);

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: asInt(json['id']) ?? 0,
        item: json['item'] is Map<String, dynamic>
            ? Item.fromJson(json['item'] as Map<String, dynamic>)
            : null,
        variant: asInt(json['variant']),
        sizeGroup: json['size_group'] as String?,
        size: json['size'] as String?,
        itemName: json['item_name'] as String?,
        itemPrice: json['item_price'] as String?,
        variantImage: json['variant_image'] as String?,
        quantity: asInt(json['quantity']) ?? 0,
        originalQuantity: asInt(json['original_quantity']),
        packedQuantity: asInt(json['packed_quantity']),
        pieceCount: asInt(json['piece_count']),
        order: asInt(json['order']),
        variantDisplayOrder: s(json['variant_display_order']),
      );

<<<<<<< HEAD
  OrderItem copyWith({int? packedQuantity}) => OrderItem(
        id: id,
        item: item,
        variant: variant,
        sizeGroup: sizeGroup,
=======
  OrderItem copyWith({int? quantity, String? sizeGroup, int? packedQuantity}) =>
      OrderItem(
        id: id,
        item: item,
        variant: variant,
        sizeGroup: sizeGroup ?? this.sizeGroup,
>>>>>>> dev
        size: size,
        itemName: itemName,
        itemPrice: itemPrice,
        variantImage: variantImage,
<<<<<<< HEAD
        quantity: quantity,
=======
        quantity: quantity ?? this.quantity,
>>>>>>> dev
        originalQuantity: originalQuantity,
        packedQuantity: packedQuantity ?? this.packedQuantity,
        pieceCount: pieceCount,
        variantDisplayOrder: variantDisplayOrder,
        order: order,
      );
}

@immutable
class Order {
  const Order({
    required this.id,
    required this.items,
    required this.agent,
    required this.customer,
    required this.totalSets,
    required this.totalPieces,
    this.status,
    required this.createdAt,
    this.expectedDeliveryDate,
    this.preferredTransport,
    this.preferredTransportName,
    this.transportCompany,
    this.transportCompanyName,
    this.lrNumber,
    this.notes,
    this.totalQuantity,
  });

  final int id;
  final List<OrderItem> items;
  final SimpleAgent agent;
  final SimpleCustomer customer;
  final String? totalQuantity;
  final int totalSets;
  final int totalPieces;
  final String? status;
  final String createdAt;
  final String? expectedDeliveryDate;
  final int? preferredTransport;
  final String? preferredTransportName;
  final int? transportCompany;
  final String? transportCompanyName;
  final String? lrNumber;
  final String? notes;

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: asInt(json['id']) ?? 0,
        items: asList(json['items'], OrderItem.fromJson),
        agent: json['agent_details'] == null
            ? const SimpleAgent(id: 0)
            : SimpleAgent.fromJson(json['agent_details'] as Map<String, dynamic>),
        customer: json['customer_details'] == null
            ? const SimpleCustomer(id: 0, name: '')
            : SimpleCustomer.fromJson(json['customer_details'] as Map<String, dynamic>),
        totalQuantity: json['total_quantity'] as String?,
        totalSets: asInt(json['total_sets']) ?? 0,
        totalPieces: asInt(json['total_pieces']) ?? 0,
        status: json['status'] as String?,
        createdAt: s(json['created_at']),
        expectedDeliveryDate: json['expected_delivery_date'] as String?,
        preferredTransport: asInt(json['preferred_transport']),
        preferredTransportName: json['preferred_transport_name'] as String?,
        transportCompany: asInt(json['transport_company']),
        transportCompanyName: json['transport_company_name'] as String?,
        lrNumber: s(json['lr_number']),
        notes: json['notes'] as String?,
      );

  Order copyWith({List<OrderItem>? items, String? status}) => Order(
        id: id,
        items: items ?? this.items,
        agent: agent,
        customer: customer,
        totalQuantity: totalQuantity,
        totalSets: totalSets,
        totalPieces: totalPieces,
        status: status ?? this.status,
        createdAt: createdAt,
        expectedDeliveryDate: expectedDeliveryDate,
        preferredTransport: preferredTransport,
        preferredTransportName: preferredTransportName,
        transportCompany: transportCompany,
        transportCompanyName: transportCompanyName,
        lrNumber: lrNumber,
        notes: notes,
      );
}

@immutable
class OrderLog {
  const OrderLog({
    required this.id,
    this.action,
    this.performedBy,
    this.createdAt,
    this.details,
  });
  final int id;
  final String? action;
  final String? performedBy;
  final String? createdAt;
  final String? details;

  factory OrderLog.fromJson(Map<String, dynamic> json) => OrderLog(
        id: asInt(json['id']) ?? 0,
        action: json['action'] as String?,
        performedBy: json['performed_by'] as String?,
        createdAt: json['created_at'] as String?,
        details: json['details'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Customer
// ---------------------------------------------------------------------------

@immutable
class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.address,
    this.contact,
    required this.agent,
    this.agentName,
    this.gst,
    this.preferredTransport,
    this.preferredTransportName,
    this.totalOrders,
  });
  final int id;
  final String name;
  final String? address;
  final String? contact;
  final int agent;
  final String? agentName;
  final String? gst;
  final int? preferredTransport;
  final String? preferredTransportName;
  final String? totalOrders;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: asInt(json['id']) ?? 0,
        name: s(json['name']),
        address: json['address'] as String?,
        contact: json['contact'] as String?,
        agent: asInt(json['agent']) ?? 0,
        agentName: json['agent_name'] as String?,
        gst: json['gst'] as String?,
        preferredTransport: asInt(json['preferred_transport']),
        preferredTransportName: json['preferred_transport_name'] as String?,
        totalOrders: json['total_orders']?.toString(),
      );
}

// ---------------------------------------------------------------------------
// Agent
// ---------------------------------------------------------------------------

@immutable
class AgentUser {
  const AgentUser({required this.id, this.username, this.email, this.displayName});
  final int id;
  final String? username;
  final String? email;
  final String? displayName;
  factory AgentUser.fromJson(Map<String, dynamic> json) => AgentUser(
        id: asInt(json['id']) ?? 0,
        username: json['username'] as String?,
        email: json['email'] as String?,
        displayName: json['display_name'] as String?,
      );
}

@immutable
class AssignedVariantSize {
  const AssignedVariantSize({this.id, required this.sizeRange, this.stock});
  final int? id;
  final String sizeRange;
  final int? stock;
  factory AssignedVariantSize.fromJson(Map<String, dynamic> json) =>
      AssignedVariantSize(
        id: asInt(json['id']),
        sizeRange: s(json['size_range']),
        stock: asInt(json['stock']),
      );
}

@immutable
class AgentItemVariant {
  const AgentItemVariant({
    required this.id,
    this.image,
    this.qrCode,
    required this.sizeRanges,
    this.createdAt,
  });
  final int id;
  final String? image;
  final String? qrCode;
  final List<AssignedVariantSize> sizeRanges;
  final String? createdAt;
  factory AgentItemVariant.fromJson(Map<String, dynamic> json) => AgentItemVariant(
        id: asInt(json['id']) ?? 0,
        image: json['image'] as String?,
        qrCode: json['qr_code'] as String?,
        sizeRanges: asList(json['size_ranges'], AssignedVariantSize.fromJson),
        createdAt: json['created_at'] as String?,
      );
}

@immutable
class AssignedItem {
  const AssignedItem({required this.id, required this.name, this.type, required this.price, required this.variants});
  final int id;
  final String name;
  final String? type;
  final String price;
  final List<AgentItemVariant> variants;
  factory AssignedItem.fromJson(Map<String, dynamic> json) => AssignedItem(
        id: asInt(json['id']) ?? 0,
        name: s(json['name']),
        type: json['type'] as String?,
        price: s(json['price']),
        variants: asList(json['variants'], AgentItemVariant.fromJson),
      );
}

@immutable
class Agent {
  const Agent({
    required this.id,
    required this.user,
    this.contact,
    this.totalCustomers,
    this.assignedItems,
  });
  final int id;
  final AgentUser user;
  final String? contact;
  final String? totalCustomers;
  final List<AssignedItem>? assignedItems;

  String get displayName =>
      user.displayName?.isNotEmpty == true
          ? user.displayName!
          : (user.username ?? 'Agent ${user.id}');

  factory Agent.fromJson(Map<String, dynamic> json) => Agent(
        id: asInt(json['id']) ?? 0,
        user: json['user'] is Map<String, dynamic>
            ? AgentUser.fromJson(json['user'] as Map<String, dynamic>)
            : AgentUser(id: asInt(json['id']) ?? 0, username: json['username'] as String?),
        contact: json['contact'] as String?,
        totalCustomers: json['total_customers']?.toString(),
        assignedItems: json['assigned_items'] == null
            ? null
            : asList(json['assigned_items'], AssignedItem.fromJson),
      );

  Map<String, dynamic> toCreateJson() => {
        'username': user.username,
        'email': user.email,
        'password': '',
        'display_name': user.displayName,
        'contact': contact,
      };
}

// ---------------------------------------------------------------------------
// Transport
// ---------------------------------------------------------------------------

@immutable
class Transport {
  const Transport({required this.id, required this.name, this.isActive, this.createdAt});
  final int id;
  final String name;
  final bool? isActive;
  final String? createdAt;
  factory Transport.fromJson(Map<String, dynamic> json) => Transport(
        id: asInt(json['id']) ?? 0,
        name: s(json['name']),
        isActive: json['is_active'] as bool?,
        createdAt: json['created_at'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Dashboard analytics
// ---------------------------------------------------------------------------

@immutable
class AnalyticsKpis {
  const AnalyticsKpis({
    this.total = 0,
    this.draft = 0,
    this.pending = 0,
    this.editing = 0,
    this.packed = 0,
    this.dispatched = 0,
    this.totalValue,
    this.totalSets,
    this.totalPieces,
  });
  final int total;
  final int draft;
  final int pending;
  final int editing;
  final int packed;
  final int dispatched;
  final double? totalValue;
  final int? totalSets;
  final int? totalPieces;
  factory AnalyticsKpis.fromJson(Map<String, dynamic> json) => AnalyticsKpis(
        total: asInt(json['total']) ?? 0,
        draft: asInt(json['draft']) ?? 0,
        pending: asInt(json['pending']) ?? 0,
        editing: asInt(json['editing']) ?? 0,
        packed: asInt(json['packed']) ?? 0,
        dispatched: asInt(json['dispatched']) ?? 0,
        totalValue: (json['total_value'] as num?)?.toDouble(),
        totalSets: asInt(json['total_sets']),
        totalPieces: asInt(json['total_pieces']),
      );
}

@immutable
class TrendPoint {
  const TrendPoint({this.day, this.count});
  final String? day;
  final int? count;
  factory TrendPoint.fromJson(Map<String, dynamic> json) =>
      TrendPoint(day: json['day'] as String?, count: asInt(json['count']));
}

@immutable
class LeaderboardEntry {
  const LeaderboardEntry({this.id, this.name, this.count});
  final int? id;
  final String? name;
  final int? count;
  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        id: asInt(json['id']),
        name: json['name'] as String? ?? json['username'] as String?,
        count: asInt(json['count'] ?? json['qty']),
      );
}

@immutable
class TimeMetrics {
  const TimeMetrics({this.avgDispatchHours, this.medianDispatchHours, this.dispatchedWithin24hPct});
  final double? avgDispatchHours;
  final double? medianDispatchHours;
  final double? dispatchedWithin24hPct;
  factory TimeMetrics.fromJson(Map<String, dynamic> json) => TimeMetrics(
        avgDispatchHours: (json['avg_dispatch_hours'] as num?)?.toDouble(),
        medianDispatchHours: (json['median_dispatch_hours'] as num?)?.toDouble(),
        dispatchedWithin24hPct: (json['dispatched_within_24h_pct'] as num?)?.toDouble(),
      );
}

@immutable
class AnalyticsData {
  const AnalyticsData({
    required this.kpis,
    required this.trend,
    required this.topCustomers,
    required this.topAgents,
    required this.topItems,
    this.timeMetrics,
  });
  final AnalyticsKpis kpis;
  final List<TrendPoint> trend;
  final List<LeaderboardEntry> topCustomers;
  final List<LeaderboardEntry> topAgents;
  final List<LeaderboardEntry> topItems;
  final TimeMetrics? timeMetrics;

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    final rawTrend = json['trend'];
    assert(
      rawTrend is List,
      'Analytics payload mismatch: expected json["trend"] to be a list of '
      '{"day": "YYYY-MM-DD", "count": int} points but got '
      '${rawTrend == null ? 'null' : rawTrend.runtimeType}. Fix the backend '
      'contract or update AnalyticsData parsing before shipping — otherwise '
      'trend data is silently dropped.',
    );
    return AnalyticsData(
      kpis: json['kpis'] is Map<String, dynamic>
          ? AnalyticsKpis.fromJson(json['kpis'] as Map<String, dynamic>)
          : const AnalyticsKpis(),
      trend: asList(rawTrend, TrendPoint.fromJson),
      topCustomers: asList(json['top_customers'], LeaderboardEntry.fromJson),
      topAgents: asList(json['top_agents'], LeaderboardEntry.fromJson),
      topItems: asList(json['top_items'], LeaderboardEntry.fromJson),
      timeMetrics: json['time_metrics'] is Map<String, dynamic>
          ? TimeMetrics.fromJson(json['time_metrics'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String? _sizeGroupForItem(Item item, int variantId) {
  for (final v in item.variants) {
    if (v.id == variantId && v.sizes.isNotEmpty) {
      return v.sizes.first.sizeRange ?? v.sizes.first.size;
    }
  }
  return null;
}