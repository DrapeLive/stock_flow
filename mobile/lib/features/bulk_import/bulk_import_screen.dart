import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/text_symbols.dart';
import '../../data/repositories.dart';
import '../../shared/widgets.dart';

/// Mirrors `app/(admin-no-layout)/admin/bulk-import/page.tsx`.
class BulkImportScreen extends ConsumerStatefulWidget {
  const BulkImportScreen({super.key});

  @override
  ConsumerState<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _CustomerRow {
  _CustomerRow()
      : id = _uid(),
        name = '',
        address = '',
        contact = '',
        agent = '',
        gst = '',
        transport = '';
  final String id;
  String name, address, contact, agent, gst, transport;
  String? backendError;
}

class _BackendError {
  const _BackendError({required this.row, required this.name, required this.error});
  final int row;
  final String name;
  final String error;
}

typedef _FieldKey = String;

const _fields = <({String key, String label, bool required, String hint})>[
  (key: 'name', label: 'Customer Name', required: true, hint: 'John Doe'),
  (key: 'address', label: 'Address', required: false, hint: '123 Main St'),
  (key: 'contact', label: 'Contact', required: true, hint: '+91 98765 43210'),
  (key: 'agent', label: 'Agent', required: true, hint: 'agent username'),
  (key: 'gst', label: 'GST No.', required: false, hint: '22AAAAA0000A1Z5'),
  (key: 'transport', label: 'Transport', required: false, hint: 'Transport name'),
];

Map<String, String> _normalizeRow(Map<String, dynamic> raw) {
  final lower = <String, String>{};
  raw.forEach((k, v) {
    lower[k.toLowerCase().trim().replaceAll('.', '')] = '$v';
  });
  return {
    'name': lower['name'] ?? lower['customer name'] ?? '',
    'address': lower['address'] ?? '',
    'contact': lower['contact'] ?? lower['phone'] ?? lower['mobile'] ?? '',
    'agent': lower['agent'] ?? lower['agent name'] ?? '',
    'gst': lower['gst'] ?? lower['gst no'] ?? lower['gstin'] ?? '',
    'transport': lower['transport'] ?? lower['transport name'] ?? '',
  };
}

class _BulkImportScreenState extends ConsumerState<BulkImportScreen> {
  String _fileName = '';
  String _status = 'idle';
  final List<_CustomerRow> _rows = [];
  final Map<String, Set<_FieldKey>> _errors = {};
  final Set<String> _selected = {};
  final List<_BackendError> _backendErrors = [];
  bool _showModal = false;
  ({int created, int failed})? _importResult;
  bool _saving = false;

  bool _rowInvalid(_CustomerRow r) => _errors[r.id]?.isNotEmpty ?? false;

  void _validateRow(_CustomerRow r) {
    final missing = <_FieldKey>{};
    for (final f in _fields) {
      if (f.required && _get(r, f.key).trim().isEmpty) missing.add(f.key);
    }
    _errors[r.id] = missing;
  }

  String _get(_CustomerRow r, String key) {
    switch (key) {
      case 'name':
        return r.name;
      case 'address':
        return r.address;
      case 'contact':
        return r.contact;
      case 'agent':
        return r.agent;
      case 'gst':
        return r.gst;
      default:
        return r.transport;
    }
  }

  void _set(_CustomerRow r, String key, String value) {
    switch (key) {
      case 'name':
        r.name = value;
      case 'address':
        r.address = value;
      case 'contact':
        r.contact = value;
      case 'agent':
        r.agent = value;
      case 'gst':
        r.gst = value;
      default:
        r.transport = value;
    }
    r.backendError = null;
    setState(() => _validateRow(r));
  }

  void _clearAll() {
    setState(() {
      _rows.clear();
      _fileName = '';
      _status = 'idle';
      _errors.clear();
      _selected.clear();
      _backendErrors.clear();
    });
  }

  Future<void> _pickFile() async {
    if (_status == 'saving') return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      _parseBytes(file.name, file.bytes);
    } catch (e) {
      if (mounted) AppToast.error(context, 'Could not open file: $e');
    }
  }

  void _parseBytes(String name, Uint8List? bytes) {
    if (bytes == null) return;
    final ext = name.split('.').last.toLowerCase();
    if (!const ['xlsx', 'xls', 'csv'].contains(ext)) {
      AppToast.error(context, 'Only .xlsx, .xls or .csv files supported');
      return;
    }
    setState(() {
      _fileName = name;
      _status = 'parsing';
    });
    try {
      List<Map<String, dynamic>> rawRows;
      if (ext == 'csv') {
        rawRows = _parseCsv(utf8.decode(bytes));
      } else {
        final book = excel.Excel.decodeBytes(bytes);
        final sheet = book.tables.values.isNotEmpty
            ? book.tables.values.first
            : null;
        if (sheet == null) {
          rawRows = const [];
        } else {
          rawRows = _parseSheetRows(sheet);
        }
      }
      final parsed = rawRows.map((m) {
        final r = _CustomerRow();
        final n = _normalizeRow(m);
        r.name = n['name'] ?? '';
        r.address = n['address'] ?? '';
        r.contact = n['contact'] ?? '';
        r.agent = n['agent'] ?? '';
        r.gst = n['gst'] ?? '';
        r.transport = n['transport'] ?? '';
        return r;
      }).toList();
      setState(() {
        _rows
          ..clear()
          ..addAll(parsed);
        _errors.clear();
        for (final r in _rows) {
          _validateRow(r);
        }
        _selected.clear();
        _backendErrors.clear();
        _status = 'ready';
      });
      if (mounted) {
        AppToast.success(context, '${parsed.length} rows loaded');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'error');
        AppToast.error(context, 'Failed to parse file $kEmDash check the format.');
      }
    }
  }

  List<Map<String, dynamic>> _parseSheetRows(excel.Sheet sheet) {
    final rows = sheet.rows;
    if (rows.isEmpty) return const [];
    final headers = rows.first.map((c) => _cellText(c)).toList();
    final out = <Map<String, dynamic>>[];
    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i];
      final map = <String, dynamic>{};
      for (var j = 0; j < headers.length; j++) {
        if (j < cells.length) map[headers[j]] = _cellText(cells[j]);
      }
      out.add(map);
    }
    return out;
  }

String _cellText(excel.Data? cell) {
  if (cell == null) return '';
  return '${cell.value}';
}

  List<Map<String, dynamic>> _parseCsv(String text) {
    final rows = <List<String>>[];
    final current = StringBuffer();
    var inQuotes = false;
    final rowBuf = <String>[];
    void flush() {
      rowBuf.add(current.toString());
      current.clear();
      if (rowBuf.isNotEmpty) {
        rows.add(List.of(rowBuf));
        rowBuf.clear();
      }
    }

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '"') {
        if (inQuotes && i + 1 < text.length && text[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        rowBuf.add(current.toString());
        current.clear();
      } else if ((c == '\n' || c == '\r') && !inQuotes) {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        flush();
      } else {
        current.write(c);
      }
    }
    flush();
    if (rows.isEmpty) return const [];
    final headers = rows.first.map((h) => h.trim()).toList();
    final out = <Map<String, dynamic>>[];
    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i];
      final map = <String, dynamic>{};
      for (var j = 0; j < headers.length; j++) {
        if (j < cells.length) map[headers[j]] = cells[j].trim();
      }
      out.add(map);
    }
    return out;
  }

  Future<void> _downloadTemplate() async {
    try {
      final book = excel.Excel.createExcel();
      final sheet = book['Customers'];
      sheet
        ..appendRow([
          excel.TextCellValue('Customer Name'),
          excel.TextCellValue('Address'),
          excel.TextCellValue('Contact'),
          excel.TextCellValue('Agent'),
          excel.TextCellValue('GST No.'),
          excel.TextCellValue('Transport'),
        ])
        ..appendRow([
          excel.TextCellValue('John Doe'),
          excel.TextCellValue('123 Main St, Chennai'),
          excel.TextCellValue('+91 98765 43210'),
          excel.TextCellValue('agent_username'),
          excel.TextCellValue('22AAAAA0000A1Z5'),
          excel.TextCellValue('FastCargo'),
        ])
        ..appendRow([
          excel.TextCellValue('Jane Smith'),
          excel.TextCellValue('456 Park Ave, Mumbai'),
          excel.TextCellValue('+91 91234 56789'),
          excel.TextCellValue('agent_username'),
          excel.TextCellValue(''),
          excel.TextCellValue(''),
        ]);
      final bytes = book.encode() ?? const <int>[];
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/customer_import_template.xlsx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)],
          subject: 'customer_import_template.xlsx');
    } catch (e) {
      if (mounted) AppToast.error(context, 'Could not share template: $e');
    }
  }

  void _deleteRow(_CustomerRow r) {
    setState(() {
      _rows.remove(r);
      _errors.remove(r.id);
      _selected.remove(r.id);
    });
  }

  void _deleteSelected() {
    setState(() {
      _rows.removeWhere((r) => _selected.contains(r.id));
      _errors.removeWhere((k, _) => _selected.contains(k));
      _selected.clear();
    });
  }

  void _addRow() {
    setState(() => _rows.add(_CustomerRow()));
  }

  void _toggleSelect(_CustomerRow r) {
    setState(() {
      if (_selected.contains(r.id)) {
        _selected.remove(r.id);
      } else {
        _selected.add(r.id);
      }
    });
  }

  void _removeFailedRows() {
    final failedNames = _backendErrors.map((e) => e.name).toSet();
    setState(() {
      _rows.removeWhere((r) => failedNames.contains(r.name));
      _errors.clear();
      for (final r in _rows) {
        _validateRow(r);
      }
      _backendErrors.clear();
    });
  }

  Future<void> _handleConfirm() async {
    final hasInvalid = _rows.any(_rowInvalid);
    if (_rows.isEmpty) {
      AppToast.error(context, 'Add at least one row before saving');
      return;
    }
    if (hasInvalid) {
      final n = _errors.values.where((e) => e.isNotEmpty).length;
      setState(() {});
      AppToast.error(context, 'Fix $n invalid row(s) before saving');
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = _rows
          .map((r) => {
                'name': r.name,
                'address': r.address,
                'contact': r.contact,
                'agent': r.agent,
                'gst': r.gst,
                'transport': r.transport,
              })
          .toList();
      final res = await repos.customer.bulkImport(payload);
      _backendErrors
        ..clear()
        ..addAll(res.errors
            .map((e) =>
                _BackendError(row: e.$1, name: e.$2, error: e.$3))
            .toList());
      final errByName = {for (final e in _backendErrors) e.name: e.error};
      for (final r in _rows) {
        r.backendError = errByName[r.name];
      }
      if (mounted) {
        setState(() {
          _importResult = (created: res.created, failed: _backendErrors.length);
          _showModal = true;
          _saving = false;
        });
        _showResultModal();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.error(context, 'Save failed: ${ApiClient.mapError(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
final invalidCount = _errors.values.where((e) => e.isNotEmpty).length;
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFBFA),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF9CA3AF)),
          onPressed: () => context.canPop()
            ? context.pop()
            : context.go('/admin/profile'),
        ),
        title: const Text('Batch Import',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.black)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.upload_outlined,
                      size: 30, color: AppColors.primary),
                ),
                const SizedBox(height: 10),
                const Text('Bulk Import',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black)),
                const Text('UPLOAD $kMiddleDot REVIEW $kMiddleDot SAVE',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Color(0xFF9CA3AF))),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _downloadTemplate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.download, size: 14),
                  label: const Text('Download Template (.xlsx)',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Upload zone
          InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(_fileName.isEmpty ? 32 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1.6,
                ),
              ),
              child: _fileName.isEmpty
                  ? const Column(
                      children: [
                        Icon(Icons.file_upload_outlined,
                            size: 40, color: Color(0xFF9CA3AF)),
                        SizedBox(height: 8),
                        Text('Drop your spreadsheet here',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF374151))),
                        SizedBox(height: 4),
                        Text('or tap to browse $kEmDash .xlsx, .xls, .csv',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF))),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.description_outlined,
                              size: 20, color: Color(0xFF3B82F6)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1F2937))),
                              Text(
                                  '${_rows.length} rows loaded $kMiddleDot Tap to replace',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9CA3AF))),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: _clearAll,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Clear',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF43F5E))),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Toolbar + rows
          if (_status == 'parsing')
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primary),
              ),
            )
          else if (_rows.isNotEmpty) ...[
            Row(
              children: [
                Text('${_rows.length} rows',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B7280))),
                const SizedBox(width: 8),
                if (_selected.isNotEmpty)
                  _badge('${_selected.length} selected', AppColors.primary),
                if (invalidCount > 0)
                  _badge('$invalidCount invalid', const Color(0xFFF43F5E)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_backendErrors.isNotEmpty)
                    _toolbarButton(
                      label: 'Remove ${_backendErrors.length} failed',
                      color: const Color(0xFFB45309),
                      bg: const Color(0xFFFFF7ED),
                      onTap: _removeFailedRows,
                    ),
                  if (_selected.isNotEmpty)
                    _toolbarButton(
                      label: 'Delete ${_selected.length}',
                      color: const Color(0xFFF43F5E),
                      bg: const Color(0xFFFFF1F2),
                      onTap: _deleteSelected,
                    ),
                  _toolbarButton(
                    label: 'Add Row',
                    color: const Color(0xFF4B5563),
                    bg: Colors.white,
                    onTap: _addRow,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _rows.length; i++) ...[
              _rowCard(_rows[i], i),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: invalidCount > 0
                    ? const Color(0xFFFFF1F2)
                    : AppColors.primary,
                foregroundColor: invalidCount > 0
                    ? const Color(0xFFF43F5E)
                    : Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _saving ? null : _handleConfirm,
              icon: _saving
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 17),
              label: Text(
                _saving
                    ? 'Saving$kEllipsis'
                    : invalidCount > 0
                        ? 'Fix $invalidCount error(s)'
                        : 'Save ${_rows.length} Customers',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ] else if (_status == 'idle')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.table_chart_outlined,
                        size: 44, color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 8),
                    Text('Upload a spreadsheet to get started',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF9CA3AF))),
                  ],
                ),
              ),
            ),
],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w900, color: color)),
    );
  }

  Widget _toolbarButton(
      {required String label,
      required Color color,
      required Color bg,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: color.withValues(alpha: 0.15)),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ),
      ),
    );
  }

  Widget _rowCard(_CustomerRow row, int index) {
    final selected = _selected.contains(row.id);
    final missing = _errors[row.id] ?? const <_FieldKey>{};
    final hasBackend = row.backendError != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (missing.isNotEmpty || hasBackend)
              ? const Color(0xFFFB7185)
              : const Color(0xFFF3F4F6),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: selected,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  onChanged: (_) => _toggleSelect(row),
                ),
              ),
              Text('${index + 1}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD1D5DB))),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: hasBackend
                          ? const Color(0xFFFFF7ED)
                          : missing.isNotEmpty
                              ? const Color(0xFFFFF1F2)
                              : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hasBackend
                          ? 'Duplicate'
                          : missing.isNotEmpty
                              ? 'Invalid'
                              : 'OK',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: hasBackend
                              ? const Color(0xFFB45309)
                              : missing.isNotEmpty
                                  ? const Color(0xFFF43F5E)
                                  : const Color(0xFF16A34A)),
                    ),
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => _deleteRow(row),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.delete_outline,
                      size: 15, color: Color(0xFFF43F5E)),
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: Color(0xFFF9FAFB)),
          for (final f in _fields)
            _editableCell(
              rowId: row.id,
              label: f.label,
              hint: f.hint,
              required: f.required,
              value: _get(row, f.key),
              hasError: missing.contains(f.key),
              onChanged: (v) => _set(row, f.key, v),
            ),
          if (hasBackend)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      size: 14, color: Color(0xFFB45309)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(row.backendError!,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309))),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _editableCell({
      required String rowId,
      required String label,
      required String hint,
      required bool required,
      required String value,
      required bool hasError,
      required ValueChanged<String> onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        key: ValueKey('$rowId-$label'),
        onChanged: onChanged,
        initialValue: value,
        style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
        decoration: InputDecoration(
          labelText: '$label${required ? ' *' : ''}',
          labelStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF)),
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFE5E7EB)),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(
                color: hasError ? const Color(0xFFFB7185) : AppColors.primary),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
          ),
          filled: true,
          fillColor: hasError
              ? const Color(0xFFFFF5F5)
              : Colors.transparent,
        ),
      ),
    );
  }

  Future<void> _onDone() async {
    setState(() {
      _showModal = false;
    });
    if (_backendErrors.isEmpty) {
      _clearAll();
      AppToast.success(context, 'All customers imported successfully');
    }
  }

  void _showResultModal() {
    final result = _importResult;
    if (result == null || !_showModal) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Import Complete',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.black)),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: Color(0xFFD1D5DB)),
                    onPressed: () {
                      setState(() => _showModal = false);
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${result.created}',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF15803D))),
                          const Text('Saved successfully',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF22C55E))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${result.failed}',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFE11D48))),
                          const Text('Failed',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFB7185))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_backendErrors.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('FAILED ROWS',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: Color(0xFF9CA3AF))),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final e in _backendErrors)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFFECDD3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 14, color: Color(0xFFFB7185)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text.rich(TextSpan(
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4B5563)),
                                  children: [
                                    TextSpan(
                                        text: 'Row ${e.row}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFFE11D48))),
                                    if (e.name.isNotEmpty)
                                      TextSpan(text: ' $kMiddleDot ${e.name}'),
                                    TextSpan(
                                        text: '\n${e.error}',
                                        style: const TextStyle(
                                            color: Color(0xFFF43F5E))),
                                  ],
                                )),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_backendErrors.isNotEmpty)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF43F5E),
                        side: const BorderSide(color: Color(0xFFFECDD3)),
                        backgroundColor: const Color(0xFFFFF1F2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      onPressed: () {
                        _removeFailedRows();
                        setState(() => _showModal = false);
                        Navigator.of(ctx).pop();
                      },
                      child: Text('Remove ${_backendErrors.length} failed',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900)),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                    onPressed: _onDone,
                    child: const Text('Done',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _uid() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);