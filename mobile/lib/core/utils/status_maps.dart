import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum OrderStatus {
  draft,
  pending,
  editing,
  packed,
  dispatched,
  unknown;

  static OrderStatus from(String? raw) {
    if (raw == null) return unknown;
    switch (raw.toUpperCase()) {
      case 'DRAFT':
        return OrderStatus.draft;
      case 'PENDING':
        return OrderStatus.pending;
      case 'EDITING':
        return OrderStatus.editing;
      case 'PACKED':
        return OrderStatus.packed;
      case 'DISPATCHED':
        return OrderStatus.dispatched;
      default:
        return unknown;
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.draft:
        return 'Draft';
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.editing:
        return 'Editing';
      case OrderStatus.packed:
        return 'Packed';
      case OrderStatus.dispatched:
        return 'Dispatched';
      case OrderStatus.unknown:
        return '';
    }
  }

  String get raw {
    switch (this) {
      case OrderStatus.draft:
        return 'DRAFT';
      case OrderStatus.pending:
        return 'PENDING';
      case OrderStatus.editing:
        return 'EDITING';
      case OrderStatus.packed:
        return 'PACKED';
      case OrderStatus.dispatched:
        return 'DISPATCHED';
      case OrderStatus.unknown:
        return '';
    }
  }
}

/// (background, foreground) pair matching `components/ui/custom/StatusBadge.tsx`.
(Color, Color) statusBadgeColors(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return (AppColors.pendingBg, AppColors.pendingFg);
    case OrderStatus.packed:
      return (AppColors.packedBg, AppColors.packedFg);
    case OrderStatus.dispatched:
      return (AppColors.dispatchedBg, AppColors.dispatchedFg);
    default:
      return (AppColors.grayBg, AppColors.grayFg);
  }
}

Color statusBarColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return AppColors.pending;
    case OrderStatus.packed:
      return AppColors.primary;
    case OrderStatus.dispatched:
      return AppColors.dispatched;
    default:
      return AppColors.textMuted;
  }
}