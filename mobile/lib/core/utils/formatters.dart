import 'package:intl/intl.dart';

import 'text_symbols.dart';

final NumberFormat _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '\u20B9',
  decimalDigits: 2,
);

String formatInr(num value) => _inr.format(value);

String formatInrInt(num value) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0)
        .format(value);

final DateFormat _apiDate = DateFormat('yyyy-MM-dd');

String toApiDate(DateTime d) => _apiDate.format(d);

final DateFormat _displayDate = DateFormat('dd MMM yyyy');

DateTime? _parseToLocal(String iso) {
  try {
    return DateTime.parse(iso).toLocal();
  } catch (_) {
    return null;
  }
}

String formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return kEmDash;
  final date = _parseToLocal(iso);
  return date == null ? iso : _displayDate.format(date);
}

/// e.g. "12 Jan" — matches OrderCard's `day: "2-digit", month: "short"`.
String formatDateShort(String? iso) {
  if (iso == null || iso.isEmpty) return kEmDash;
  final date = _parseToLocal(iso);
  return date == null ? iso : DateFormat('dd MMM').format(date);
}

String formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return kEmDash;
  final date = _parseToLocal(iso);
  return date == null ? iso : DateFormat('dd MMM yyyy, hh:mm a').format(date);
}

/// Human-readable set count, e.g. "1 Set" / "2 Sets".
String formatSets(int count) => '$count ${count == 1 ? 'Set' : 'Sets'}';

/// Human-readable piece count, e.g. "1 pc" / "9 pcs".
String formatPieces(int count) => '$count ${count == 1 ? 'pc' : 'pcs'}';

/// Countdown label for the archived-items list, e.g. "Deletes in 7 days".
String archiveCountdownLabel(int daysUntilPurge) {
  if (daysUntilPurge <= 0) return 'Deletes today';
  if (daysUntilPurge == 1) return 'Deletes in 1 day';
  return 'Deletes in $daysUntilPurge days';
}

/// Number of active dashboard filters (date range, agent, customer).
int activeFilterCount({
  String from = '',
  String to = '',
  int? agent,
  int? customer,
}) {
  var count = 0;
  if (from.isNotEmpty) count++;
  if (to.isNotEmpty) count++;
  if (agent != null) count++;
  if (customer != null) count++;
  return count;
}