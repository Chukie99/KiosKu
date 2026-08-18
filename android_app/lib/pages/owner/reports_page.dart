import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../../api.dart';
import '../../components.dart';
import '../../models.dart';
import '../../providers.dart';
import '../../theme.dart';
import 'owner_components.dart';

class OwnerReportsPage extends ConsumerStatefulWidget {
  const OwnerReportsPage({super.key});

  @override
  ConsumerState<OwnerReportsPage> createState() => _OwnerReportsPageState();
}

class _OwnerReportsPageState extends ConsumerState<OwnerReportsPage> {
  late DateTime _from;
  late DateTime _to;
  bool _loading = false;
  List<Transaction> _transactions = [];
  DailyReport? _daily;
  MonthlyReport? _monthly;

  @override
  void initState() {
    super.initState();
    _to = DateTime.now();
    _from = _to.subtract(const Duration(days: 29));
    _load();
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiProvider);
      final results = await Future.wait([
        api.getTransactions(
          dateFrom: _fmt(_from),
          dateTo: _fmt(_to),
          page: 1,
        ),
        api.getReportDaily(_fmt(_from)),
        api.getReportMonthly(),
      ]);
      final page = results[0] as TxPage;
      if (!mounted) return;
      setState(() {
        _transactions = page.items;
        _daily = results[1] as DailyReport;
        _monthly = results[2] as MonthlyReport;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.offline ? 'Offline — laporan tidak dapat dimuat' : e.message,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_from.isAfter(_to)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
    _load();
  }

  Future<void> _export(String format) async {
    final dir = await getDownloadsDirectory() ??
        Directory('${Platform.environment['USERPROFILE'] ?? '.'}\\Downloads');
    final file = File(
      '${dir.path}\\laporan_${_fmt(_from)}_to_${_fmt(_to)}.$format',
    );
    try {
      await ref.read(apiProvider).exportReport(
        format: format,
        dateFrom: _fmt(_from),
        dateTo: _fmt(_to),
        savePath: file.path,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Laporan tersimpan di ${file.path}')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Map<String, double> get _dailyChart {
    final map = <String, double>{};
    for (final tx in _transactions) {
      final key = (tx.createdAt.length >= 10)
          ? tx.createdAt.substring(0, 10)
          : '';
      if (key.isEmpty) continue;
      map[key] = (map[key] ?? 0) + tx.totalAmount;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final omzetRange = _transactions.fold<double>(
      0,
      (sum, tx) => sum + tx.totalAmount,
    );
    final itemCount = _transactions.fold<double>(
      0,
      (sum, tx) => sum + tx.items.fold<double>(0, (s, i) => s + i.qty),
    );
    final chartData = _dailyChart.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () => _export('xlsx'),
            icon: const Icon(LucideIcons.fileSpreadsheet, size: 18),
            label: const Text('Export Excel'),
          ),
          TextButton.icon(
            onPressed: () => _export('pdf'),
            icon: const Icon(LucideIcons.fileText, size: 18),
            label: const Text('Export PDF'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.calendar,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () => _pickDate(true),
                          child: Text(DateFormat('dd/MM/yyyy').format(_from)),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('sampai'),
                        ),
                        OutlinedButton(
                          onPressed: () => _pickDate(false),
                          child: Text(DateFormat('dd/MM/yyyy').format(_to)),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Rentang maksimal 100 transaksi terbaru',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Transaksi (Rentang)',
                        value: '${_transactions.length} transaksi',
                        subtitle: '${itemCount.toStringAsFixed(0)} item',
                        icon: LucideIcons.receipt,
                        color: AppColors.accentGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Omzet (Rentang)',
                        value: formatRupiah(omzetRange),
                        icon: LucideIcons.banknote,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Omzet ${DateFormat('dd/MM').format(_from)}',
                        value: formatRupiah(_daily?.summary.omzet ?? 0),
                        subtitle:
                            '${_daily?.transactions ?? 0} transaksi',
                        icon: LucideIcons.sun,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Omzet Bulan Ini',
                        value: formatRupiah(_monthly?.summary.omzet ?? 0),
                        subtitle:
                            '${_monthly?.summary.totalTransactions ?? 0} transaksi',
                        icon: LucideIcons.calendarRange,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Grafik Omzet Harian',
                          icon: LucideIcons.barChart3,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 220,
                          child: chartData.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Belum ada data penjualan pada rentang ini',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                )
                              : BarChart(
                                  BarChartData(
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    titlesData: FlTitlesData(
                                      leftTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index < 0 ||
                                                index >= chartData.length) {
                                              return const SizedBox.shrink();
                                            }
                                            final date = DateTime.tryParse(
                                              chartData[index].key,
                                            );
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6,
                                              ),
                                              child: Text(
                                                date == null
                                                    ? chartData[index].key
                                                    : DateFormat('dd/MM')
                                                        .format(date),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors
                                                      .textSecondary,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    barGroups: [
                                      for (var i = 0;
                                          i < chartData.length;
                                          i++)
                                        BarChartGroupData(
                                          x: i,
                                          barRods: [
                                            BarChartRodData(
                                              toY: chartData[i].value,
                                              color: AppColors.primary,
                                              width: 18,
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                top: Radius.circular(4),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Metode Pembayaran',
                          icon: LucideIcons.pieChart,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: _paymentPie(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Daftar Transaksi',
                          icon: LucideIcons.list,
                        ),
                        const SizedBox(height: 8),
                        if (_transactions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Belum ada transaksi pada rentang ini',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Invoice')),
                                  DataColumn(label: Text('Waktu')),
                                  DataColumn(label: Text('Metode')),
                                  DataColumn(label: Text('Item')),
                                  DataColumn(
                                    label: Text('Total'),
                                    numeric: true,
                                  ),
                                  DataColumn(label: Text('Status')),
                                ],
                                rows: [
                                  for (final tx in _transactions)
                                    DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            tx.invoiceNo,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(formatDateTime(tx.createdAt)),
                                        ),
                                        DataCell(
                                          StatusBadge(
                                            text: paymentMethodLabel(
                                              tx.paymentMethod,
                                            ),
                                            color: methodColor(
                                              tx.paymentMethod,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            tx.items
                                                .fold<double>(
                                                  0,
                                                  (s, i) => s + i.qty,
                                                )
                                                .toStringAsFixed(0),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            formatRupiah(tx.totalAmount),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          StatusBadge(
                                            text: _statusLabel(tx.status),
                                            color: _statusColor(tx.status),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'selesai':
        return 'Selesai';
      case 'retur':
        return 'Retur';
      case 'void':
        return 'Void';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'selesai':
        return AppColors.success;
      case 'retur':
        return AppColors.warning;
      case 'void':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _paymentPie() {
    final methodMap = <String, double>{};
    for (final tx in _transactions) {
      final label = paymentMethodLabel(tx.paymentMethod);
      methodMap[label] = (methodMap[label] ?? 0) + tx.totalAmount;
    }
    final entries = methodMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    if (total == 0) {
      return const Center(
        child: Text(
          'Belum ada data',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }
    final colors = [
      AppColors.primary,
      AppColors.accentGreen,
      AppColors.warning,
      AppColors.danger,
      AppColors.textSecondary,
    ];
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value,
                    color: colors[i % colors.length],
                    radius: 24,
                    title: '${(entries[i].value / total * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entries[i].key,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
