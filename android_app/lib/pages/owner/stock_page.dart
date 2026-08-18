import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../api.dart';
import '../../components.dart';
import '../../models.dart';
import '../../providers.dart';
import '../../theme.dart';
import 'owner_components.dart';

class OwnerStockPage extends ConsumerStatefulWidget {
  const OwnerStockPage({super.key});

  @override
  ConsumerState<OwnerStockPage> createState() => _OwnerStockPageState();
}

class _OwnerStockPageState extends ConsumerState<OwnerStockPage> {
  bool _loading = false;
  List<StockAlert> _alerts = [];
  List<StockLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiProvider);
      final results = await Future.wait([
        api.getStockAlerts(),
        api.getStockLogs(limit: 100),
      ]);
      if (!mounted) return;
      setState(() {
        _alerts = results[0] as List<StockAlert>;
        _logs = results[1] as List<StockLog>;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.offline ? 'Offline — data stok tidak dapat dimuat' : e.message,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAdjustDialog(StockAlert alert) async {
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Koreksi Stok'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${alert.name} — stok saat ini ${alert.stock.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: qtyController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Jumlah perubahan (+/−)',
                  hintText: 'Contoh: 10 atau -5',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Alasan *',
                  hintText: 'Contoh: restock, barang rusak',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    if (submitted != true) return;
    final changeQty = double.tryParse(qtyController.text.trim());
    final reason = reasonController.text.trim();
    if (changeQty == null || changeQty == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah perubahan tidak boleh 0')),
      );
      return;
    }
    if (reason.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alasan wajib diisi')),
      );
      return;
    }
    try {
      final ok = await ref
          .read(apiProvider)
          .adjustStock(
            productId: alert.id,
            changeQty: changeQty,
            reason: reason,
          );
      ref.read(productsProvider.notifier).refresh();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Stok berhasil dikoreksi' : 'Gagal mengoreksi stok'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: _load,
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Alert Stok Menipis & Habis',
                          icon: LucideIcons.packageMinus,
                          trailing: _alerts.isEmpty
                              ? null
                              : StatusBadge(
                                  text: '${_alerts.length}',
                                  color: AppColors.danger,
                                ),
                        ),
                        const SizedBox(height: 8),
                        if (_alerts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Semua stok aman',
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
                                DataColumn(label: Text('Produk')),
                                DataColumn(label: Text('SKU')),
                                DataColumn(label: Text('Stok')),
                                DataColumn(label: Text('Ambang')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Aksi')),
                              ],
                              rows: [
                                for (final alert in _alerts)
                                  DataRow(
                                    cells: [
                                      DataCell(
                                        ConstrainedBox(
                                          constraints:
                                              const BoxConstraints(maxWidth: 220),
                                          child: Text(
                                            alert.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(alert.sku)),
                                      DataCell(
                                        Text(alert.stock.toStringAsFixed(0)),
                                      ),
                                      DataCell(
                                        Text(
                                          alert.stockAlertThreshold
                                              .toStringAsFixed(0),
                                        ),
                                      ),
                                      DataCell(
                                        StatusBadge(
                                          text: stockStatusLabel(
                                            alert.stock,
                                            alert.stockAlertThreshold,
                                          ),
                                          color: stockStatusColor(
                                            alert.stock,
                                            alert.stockAlertThreshold,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _openAdjustDialog(alert),
                                          icon: const Icon(
                                            LucideIcons.wrench,
                                            size: 16,
                                          ),
                                          label: const Text('Koreksi'),
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
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Riwayat Perubahan Stok',
                          icon: LucideIcons.history,
                        ),
                        const SizedBox(height: 8),
                        if (_logs.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Belum ada riwayat perubahan stok',
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
                                  DataColumn(label: Text('Waktu')),
                                  DataColumn(label: Text('Produk')),
                                  DataColumn(label: Text('Perubahan')),
                                  DataColumn(label: Text('Alasan')),
                                ],
                                rows: [
                                  for (final log in _logs)
                                    DataRow(
                                      cells: [
                                        DataCell(
                                          Text(formatDateTime(log.createdAt)),
                                        ),
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 220,
                                            ),
                                            child: Text(
                                              log.productName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            log.changeQty >= 0
                                                ? '+${log.changeQty.toStringAsFixed(0)}'
                                                : log.changeQty.toStringAsFixed(0),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: log.changeQty >= 0
                                                  ? AppColors.success
                                                  : AppColors.danger,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(log.reason.isEmpty
                                              ? '-'
                                              : log.reason),
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
}
