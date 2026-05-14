import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';

class WagesScreen extends StatefulWidget {
  const WagesScreen({super.key});

  @override
  State<WagesScreen> createState() => _WagesScreenState();
}

class _WagesScreenState extends State<WagesScreen> {
  // View toggle: true = pending download only, false = all approved
  bool _pendingOnly = true;

  // Date range (only active in 'All Approved' view)
  DateTimeRange? _dateRange;
  String _dateRangeLabel = 'Last 30 Days';

  // Department filter (client-side)
  String _deptFilter = 'All';

  // Download in-flight
  bool _downloading = false;

  Stream<List<OvertimeEntry>> get _stream {
    if (_pendingOnly) return DataService.getWagesPendingDownloadStream();
    final (from, to) = _resolvedDateRange();
    return DataService.getWagesAllApprovedStream(dateFrom: from, dateTo: to);
  }

  (DateTime?, DateTime?) _resolvedDateRange() {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (_dateRangeLabel) {
      case 'Last 30 Days':
        return (now.subtract(const Duration(days: 30)), endOfToday);
      case 'This Month':
        return (DateTime(now.year, now.month, 1), endOfToday);
      case 'This Year':
        return (DateTime(now.year, 1, 1), endOfToday);
      case 'All Time':
        return (null, null);
      case 'Custom':
        if (_dateRange != null) {
          return (
            _dateRange!.start,
            DateTime(_dateRange!.end.year, _dateRange!.end.month,
                _dateRange!.end.day, 23, 59, 59),
          );
        }
        return (null, null);
      default:
        return (now.subtract(const Duration(days: 30)), endOfToday);
    }
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
    );
    if (range != null && mounted) {
      setState(() {
        _dateRange = range;
        _dateRangeLabel = 'Custom';
      });
    }
  }

  List<OvertimeEntry> _applyDeptFilter(List<OvertimeEntry> entries) {
    if (_deptFilter == 'All') return entries;
    return entries.where((e) => e.department == _deptFilter).toList();
  }

  List<String> _availableDepts(List<OvertimeEntry> entries) {
    final depts = entries.map((e) => e.department).toSet().toList()..sort();
    return ['All', ...depts];
  }

  // ── CSV download ────────────────────────────────────────────────────────────

  void _downloadCsv(List<OvertimeEntry> entries) {
    final fmt = DateFormat('yyyy-MM-dd');
    final buffer = StringBuffer();
    buffer.writeln('OT#,Date,Clock,Employee,Department,Shift,OT Type,Hours,Reason');
    for (final e in entries) {
      final row = [
        e.overtimeNumber ?? '',
        fmt.format(e.date),
        e.clockNum,
        e.employeeName,
        e.department,
        e.shiftType,
        e.overtimeType,
        e.hours.toStringAsFixed(2),
        e.reason,
      ].map((v) => '"${v.toString().replaceAll('"', '""')}"').join(',');
      buffer.writeln(row);
    }

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'wages_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      )
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // ── PDF download ────────────────────────────────────────────────────────────

  Future<void> _downloadPdf(List<OvertimeEntry> entries) async {
    final fmt = DateFormat('dd/MM/yyyy');
    final doc = pw.Document();

    // Group by department for organised output
    final grouped = <String, List<OvertimeEntry>>{};
    for (final e in entries) {
      grouped.putIfAbsent(e.department, () => []).add(e);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'CTP Gravure — Approved Overtime',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Generated: ${DateFormat('d MMMM yyyy HH:mm').format(DateTime.now())}  ·  '
              '${entries.length} entries  ·  '
              '${entries.fold(0.0, (s, e) => s + e.hours).toStringAsFixed(1)}h total',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.Divider(height: 8),
          ],
        ),
        build: (ctx) {
          final widgets = <pw.Widget>[];
          grouped.forEach((dept, deptEntries) {
            final deptHours =
                deptEntries.fold(0.0, (s, e) => s + e.hours);
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
                child: pw.Text(
                  '$dept  ·  ${deptEntries.length} entries  ·  '
                  '${deptHours.toStringAsFixed(1)}h',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
              ),
            );
            widgets.add(
              pw.TableHelper.fromTextArray(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(
                      color: PdfColors.grey300, width: 0.5),
                ),
                headerStyle: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.blueGrey700),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.center,
                  5: pw.Alignment.center,
                  6: pw.Alignment.center,
                  7: pw.Alignment.centerLeft,
                },
                headers: [
                  'OT #',
                  'Date',
                  'Clock',
                  'Employee',
                  'Shift',
                  'OT Type',
                  'Hours',
                  'Reason',
                ],
                data: deptEntries.map((e) => [
                  e.overtimeNumber ?? '',
                  fmt.format(e.date),
                  e.clockNum,
                  e.employeeName,
                  e.shiftType,
                  e.overtimeType,
                  e.hours.toStringAsFixed(2),
                  e.reason,
                ]).toList(),
              ),
            );
          });
          return widgets;
        },
      ),
    );

    final bytes = await doc.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'wages_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      )
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // ── Confirm + download + mark ───────────────────────────────────────────────

  Future<void> _confirmAndDownload(
      BuildContext context, List<OvertimeEntry> entries, bool isPdf) async {
    final pendingCount =
        entries.where((e) => !e.downloadedByWages).length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPdf ? 'Download PDF' : 'Download CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${entries.length} entries · '
              '${entries.fold(0.0, (s, e) => s + e.hours).toStringAsFixed(1)}h total',
            ),
            if (pendingCount > 0 && !_pendingOnly) ...[
              const SizedBox(height: 8),
              Text(
                '$pendingCount of these have not been downloaded before.',
                style: const TextStyle(color: Colors.orange),
              ),
            ],
            if (_pendingOnly) ...[
              const SizedBox(height: 8),
              const Text(
                'These entries will be marked as downloaded after export.',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isPdf ? 'Download PDF' : 'Download CSV'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _downloading = true);
    try {
      if (isPdf) {
        await _downloadPdf(entries);
      } else {
        _downloadCsv(entries);
      }

      // Mark pending-only entries as downloaded after a successful export
      if (_pendingOnly) {
        final ids = entries.map((e) => e.id).toList();
        await DataService.markAsDownloadedByWages(ids);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _pendingOnly
                ? '${entries.length} entries downloaded and marked as processed'
                : '${entries.length} entries downloaded',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OvertimeEntry>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final all = snapshot.data ?? [];
        final depts = _availableDepts(all);
        final filtered = _applyDeptFilter(all);
        final totalHours =
            filtered.fold(0.0, (s, e) => s + e.hours);

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wages Download',
                          style:
                              Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${filtered.length} entries · '
                          '${totalHours.toStringAsFixed(1)}h total',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),

                  // Download buttons
                  if (filtered.isNotEmpty && !_downloading) ...[
                    OutlinedButton.icon(
                      onPressed: () =>
                          _confirmAndDownload(context, filtered, false),
                      icon: const Icon(Icons.table_chart_outlined),
                      label: const Text('CSV'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _confirmAndDownload(context, filtered, true),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDF'),
                    ),
                  ] else if (_downloading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Filter bar ───────────────────────────────────────
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Pending/All toggle
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('Pending Download'),
                            icon: Icon(Icons.download_outlined),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('All Approved'),
                            icon: Icon(Icons.history),
                          ),
                        ],
                        selected: {_pendingOnly},
                        onSelectionChanged: (s) =>
                            setState(() => _pendingOnly = s.first),
                        style: const ButtonStyle(
                          iconSize:
                              WidgetStatePropertyAll(16),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Date range (only in All Approved view)
                      if (!_pendingOnly) ...[
                        DropdownButton<String>(
                          value: _dateRangeLabel,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(
                                value: 'Last 30 Days',
                                child: Text('Last 30 Days')),
                            DropdownMenuItem(
                                value: 'This Month',
                                child: Text('This Month')),
                            DropdownMenuItem(
                                value: 'This Year',
                                child: Text('This Year')),
                            DropdownMenuItem(
                                value: 'All Time',
                                child: Text('All Time')),
                            DropdownMenuItem(
                                value: 'Custom',
                                child: Text('Custom…')),
                          ],
                          onChanged: (v) {
                            if (v == 'Custom') {
                              _pickDateRange();
                            } else {
                              setState(() => _dateRangeLabel = v!);
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Department filter
                      DropdownButton<String>(
                        value: depts.contains(_deptFilter)
                            ? _deptFilter
                            : 'All',
                        underline: const SizedBox(),
                        hint: const Text('All Departments'),
                        items: depts
                            .map((d) => DropdownMenuItem(
                                value: d, child: Text(d)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _deptFilter = v ?? 'All'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Entry list ───────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyWagesState(pendingOnly: _pendingOnly)
                    : Card(
                        margin: EdgeInsets.zero,
                        child: _WagesTable(entries: filtered),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scrollable table of wages entries
// ─────────────────────────────────────────────────────────────────────────────

class _WagesTable extends StatelessWidget {
  final List<OvertimeEntry> entries;

  const _WagesTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final theme = Theme.of(context);

    return Column(
      children: [
        // Table header
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const _TableRow(
            cells: [
              'OT #',
              'Date',
              'Clock',
              'Employee',
              'Department',
              'Shift',
              'OT Type',
              'Hours',
              'Reason',
              '',
            ],
            isHeader: true,
          ),
        ),
        const Divider(height: 1),

        // Rows
        Expanded(
          child: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 12, endIndent: 12),
            itemBuilder: (context, i) {
              final e = entries[i];
              return _TableRow(
                cells: [
                  e.overtimeNumber ?? '—',
                  dateFmt.format(e.date),
                  e.clockNum,
                  e.employeeName,
                  e.department,
                  e.shiftType,
                  e.overtimeType,
                  '${e.hours.toStringAsFixed(2)}h',
                  e.reason,
                  '',
                ],
                isHeader: false,
                downloaded: e.downloadedByWages,
              );
            },
          ),
        ),

        // Totals footer
        const Divider(height: 1),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: _TableRow(
            cells: [
              '${entries.length} entries',
              '', '', '', '', '', '',
              '${entries.fold(0.0, (s, e) => s + e.hours).toStringAsFixed(2)}h',
              '',
              '',
            ],
            isHeader: true,
          ),
        ),
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  final List<String> cells;
  final bool isHeader;
  final bool downloaded;

  const _TableRow({
    required this.cells,
    required this.isHeader,
    this.downloaded = false,
  });

  // Column flex widths: OT# | Date | Clock | Employee | Dept | Shift | OT Type | Hours | Reason | badge
  static const List<int> _flex = [3, 3, 2, 5, 4, 2, 4, 2, 6, 2];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            Expanded(
              flex: _flex[i],
              child: i == cells.length - 1
                  ? _buildBadge()
                  : Text(
                      cells[i],
                      style: isHeader
                          ? theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            )
                          : theme.textTheme.bodySmall?.copyWith(
                              color: downloaded
                                  ? Colors.grey.shade500
                                  : null,
                            ),
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge() {
    if (isHeader) return const SizedBox.shrink();
    if (!downloaded) return const SizedBox.shrink();
    return Tooltip(
      message: 'Previously downloaded',
      child: Icon(Icons.check_circle_outline,
          size: 14, color: Colors.green.shade600),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyWagesState extends StatelessWidget {
  final bool pendingOnly;
  const _EmptyWagesState({required this.pendingOnly});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            pendingOnly ? Icons.download_done : Icons.inbox_outlined,
            size: 64,
            color: pendingOnly
                ? Colors.green.shade300
                : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            pendingOnly
                ? 'All approved overtime has been downloaded'
                : 'No approved entries in the selected range',
            style: TextStyle(
                fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
