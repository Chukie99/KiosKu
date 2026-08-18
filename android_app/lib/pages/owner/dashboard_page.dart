import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../components.dart';
import '../../models.dart';
import '../../providers.dart';
import '../../theme.dart';
import 'owner_components.dart';

class OwnerDashboardPage extends ConsumerStatefulWidget {
  const OwnerDashboardPage({super.key});

  @override
  ConsumerState<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends ConsumerState<OwnerDashboardPage> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final api = ref.read(apiProvider);
    final results = await Future.wait([
      api.getReportSummary(),
      api.getReportMonthly(),
      api.getTopProducts(limit: 10),
      api.getStockAlerts(),
    ]);
    return _DashboardData(
      summary: results[0] as ReportSummary,
      monthly: results[1] as MonthlyReport,
      topProducts: results[2] as List<TopProduct>,
      alerts: results[3] as List<StockAlert>,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: _reload,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorRetry(onRetry: _reload);
          }
          final data = snapshot.data!;
          return _DashboardBody(
            data: data,
            lowStockCount: data.alerts.length,
          );
        },
      ),
    );
  }
}

class _DashboardData {
  final ReportSummary summary;
  final MonthlyReport monthly;
  final List<TopProduct> topProducts;
  final List<StockAlert> alerts;

  const _DashboardData({
    required this.summary,
    required this.monthly,
    required this.topProducts,
    required this.alerts,
  });
}

class _ErrorRetry extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorRetry({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.wifiOff,
            size: 48,
            color: AppColors.border,
          ),
          const SizedBox(height: 12),
          const Text(
            'Tidak dapat memuat data dashboard',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(LucideIcons.refreshCcw, size: 18),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final _DashboardData data;
  final int lowStockCount;

  const _DashboardBody({
    required this.data,
    required this.lowStockCount,
  });

  @override
  Widget build(BuildContext context) {
    final today = data.summary;
    final month = data.monthly.summary;
    final last7 = _last7DaysChart(data.monthly.daily);
    final total7 = last7.fold<double>(
      0,
      (sum, e) => sum + (e.y ?? 0),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Transaksi Hari Ini',
                value: '${today.totalTransactions} transaksi',
                icon: LucideIcons.receipt,
                          color: AppColors.accentGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Omzet Hari Ini',
                value: formatRupiah(today.omzet),
                subtitle: '${today.itemsSold.toStringAsFixed(0)} item terjual',
                icon: LucideIcons.banknote,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Omzet Bulan Ini',
                value: formatRupiah(month.omzet),
                subtitle: '${month.totalTransactions} transaksi',
                icon: LucideIcons.calendar,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Rata-rata Belanja',
                value: formatRupiah(today.avgBelanja),
                subtitle: 'per transaksi hari ini',
                icon: LucideIcons.shoppingCart,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        if (lowStockCount > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.alertTriangle,
                  size: 20,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$lowStockCount produk membutuhkan penambahan stok. Kelola di halaman Stok.',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Omzet 7 Hari Terakhir',
                  icon: LucideIcons.trendingUp,
                  trailing: StatusBadge(
                    text: formatRupiah(total7),
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: last7.every((e) => e.y == null || e.y == 0)
                      ? const Center(
                          child: Text(
                            'Belum ada data penjualan 7 hari terakhir',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= last7.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final date = DateTime.parse(last7[index].xLabel);
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        DateFormat('dd/MM').format(date),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: last7
                                    .map((e) => FlSpot(
                                          e.x.toDouble(),
                                          e.y ?? 0,
                                        ))
                                    .toList(),
                                isCurved: true,
                                color: AppColors.primary,
                                barWidth: 3,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppColors.primary.withOpacity(0.08),
                                ),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Top 10 Produk Terlaris',
                        icon: LucideIcons.trophy,
                        trailing: StatusBadge(
                          text: '${data.topProducts.length} produk',
                color: AppColors.accentGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (data.topProducts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Belum ada data penjualan',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      else
                        for (var i = 0; i < data.topProducts.length; i++) ...[
                          if (i > 0) const Divider(),
                          _TopProductRow(
                            rank: i + 1,
                            product: data.topProducts[i],
                          ),
                        ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Alert Stok',
                        icon: LucideIcons.packageMinus,
                        trailing: data.alerts.isEmpty
                            ? null
                            : StatusBadge(
                                text: '${data.alerts.length}',
                                color: AppColors.danger,
                              ),
                      ),
                      const SizedBox(height: 8),
                      if (data.alerts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Semua stok aman',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      else
                        for (final alert in data.alerts) ...[
                          const Divider(),
                          _AlertRow(alert: alert),
                        ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<_ChartPoint> _last7DaysChart(Map<String, double> daily) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      return _ChartPoint(x: i, y: daily[key], xLabel: key);
    });
  }
}

class _ChartPoint {
  final int x;
  final double? y;
  final String xLabel;

  const _ChartPoint({required this.x, required this.y, required this.xLabel});
}

class _TopProductRow extends StatelessWidget {
  final int rank;
  final TopProduct product;

  const _TopProductRow({required this.rank, required this.product});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: rank <= 3 ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.qtySold.toStringAsFixed(0)} terjual',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatRupiah(product.revenue),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final StockAlert alert;

  const _AlertRow({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = stockStatusColor(alert.stock, alert.stockAlertThreshold);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(LucideIcons.package, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'SKU ${alert.sku}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Stok ${alert.stock.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              StatusBadge(
                text: stockStatusLabel(alert.stock, alert.stockAlertThreshold),
                color: color,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
