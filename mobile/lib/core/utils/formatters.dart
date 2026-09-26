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

<<<<<<< HEAD
String formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return kEmDash;
  try {
    return _displayDate.format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
=======
DateTime? _parseToIst(String iso) {
  try {
    return DateTime.parse(iso).toUtc().add(const Duration(hours: 5, minutes: 30));
  } catch (_) {
    return null;
  }
}

String formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return kEmDash;
  final date = _parseToIst(iso);
  return date == null ? iso : _displayDate.format(date);
>>>>>>> dev
}

/// e.g. "12 Jan" — matches OrderCard's `day: "2-digit", month: "short"`.
String formatDateShort(String? iso) {
  if (iso == null || iso.isEmpty) return kEmDash;
<<<<<<< HEAD
  try {
    return DateFormat('dd MMM').format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
=======
  final date = _parseToIst(iso);
  return date == null ? iso : DateFormat('dd MMM').format(date);
>>>>>>> dev
}

String formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return kEmDash;
<<<<<<< HEAD
  try {
    return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
=======
  final date = _parseToIst(iso);
  return date == null ? iso : DateFormat('dd MMM yyyy, hh:mm a').format(date);
>>>>>>> dev
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