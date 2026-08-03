import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../components.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';
import 'receipt_page.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();
  List<Transaction> _items = [];
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  String _fmt(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _items = [];
        _page = 1;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final page = await ref.read(apiProvider).getTransactions(
            dateFrom: _fmt(_from),
            dateTo: _fmt(_to),
            page: _page,
          );
      if (!mounted) return;
      setState(() {
        _items = reset ? page.items : [..._items, ...page.items];
        _hasMore = _items.length < page.total;
        _loading = false;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.offline) {
        final pending = await ref.read(dbProvider).getPendingTransactions();
        if (!mounted) return;
        setState(() {
          _pending = pending;
          _items = [];
          _loading = false;
          _loadingMore = false;
        });
      } else {
        setState(() {
          _error = e.message;
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _pickRange() async {
    final from = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (from == null) return;
    if (!mounted) return;
    final to = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: from,
      lastDate: DateTime.now(),
    );
    if (to == null) return;
    setState(() {
      _from = from;
      _to = to;
    });
    await _load(reset: true);
  }

  Future<void> _showDetail(Transaction tx) async {
    Transaction full = tx;
    try {
      full = await ref.read(apiProvider).getTransaction(tx.id);
    } on ApiException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — detail tidak tersedia')),
      );
    }
    if (!mounted) return;
    final storeName =
        ref.read(settingsProvider).valueOrNull?.storeName ?? 'KiosKu';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  full.invoiceNo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatDateTime(full.createdAt),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final item in full.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.productNameSnapshot,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '${item.qty == 0 ? 1 : item.qty.toStringAsFixed(0)} x ${formatRupiah(item.pricePerUnit)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                formatRupiah(item.subtotal),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Metode',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      paymentMethodLabel(full.paymentMethod),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      formatRupiah(full.totalAmount),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReceiptPage(
                                tx: full,
                                storeName: storeName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(LucideIcons.printer, size: 18),
                        label: const Text('Cetak Ulang'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger,
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _voidTransaction(full);
                        },
                        icon: const Icon(LucideIcons.trash2, size: 18),
                        label: const Text('Void'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _voidTransaction(Transaction tx) async {
    final pinOk = await _promptPin();
    if (pinOk != true) return;
    if (!mounted) return;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Void Transaksi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${tx.invoiceNo} — ${formatRupiah(tx.totalAmount)}'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Alasan void',
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Void'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiProvider).voidTransaction(
        tx.id,
        reason: reasonController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi berhasil di-void')),
      );
      await _load(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<bool?> _promptPin() async {
    final controller = TextEditingController();
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Masukkan PIN'),
          content: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(
              labelText: 'PIN kasir',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final pin = controller.text.trim();
                if (pin.isEmpty) return;
                var ok = false;
                try {
                  final res =
                      await ref.read(apiProvider).verifyPin(pin: pin);
                  ok = res.ok;
                } on ApiException catch (e) {
                  if (e.offline) {
                    final prefs = await SharedPreferences.getInstance();
                    ok = prefs.getString('pin_hash') == hashPin(pin);
                  }
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, ok);
                }
              },
              child: const Text('Verifikasi'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectionProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickRange,
                    borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusInput,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.calendarDays,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${formatDate(_from.toIso8601String())} — '
                              '${formatDate(_to.toIso8601String())}',
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
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onPressed: () => _load(reset: true),
                  icon: const Icon(LucideIcons.refreshCcw, size: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(online),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool? online) {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: SkeletonBox(height: 72, radius: 12),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _load(reset: true),
              icon: const Icon(LucideIcons.refreshCcw, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
    if (online == false && _pending.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pending.length,
        itemBuilder: (context, index) {
          final entry = _pending[index];
          final payload = (entry['payload'] is Map)
              ? Map<String, dynamic>.from(entry['payload'] as Map)
              : <String, dynamic>{};
          final invoice = payload['invoice_no'] as String? ?? 'Transaksi';
          final createdAt = entry['created_at'] as String? ?? '';
          final items = (payload['items'] is List)
              ? (payload['items'] as List).length
              : 0;
          final method = payload['payment_method'] as String? ?? 'tunai';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(
                LucideIcons.clock,
                color: AppColors.warning,
              ),
              title: Text(
                invoice,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('$items item • ${paymentMethodLabel(method)} • ${formatDateTime(createdAt)}'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
                ),
                child: const Text(
                  'Menunggu Sinkron',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada transaksi pada rentang tanggal ini',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >
            notification.metrics.maxScrollExtent - 300) {
          if (_hasMore && !_loadingMore) {
            _page++;
            _load(reset: false);
          }
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          }
          final tx = _items[index];
          final voided = tx.status.toLowerCase() == 'void' ||
              tx.status.toLowerCase() == 'voided';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(
                paymentMethodIcon(tx.paymentMethod),
                color: voided ? AppColors.danger : AppColors.primary,
              ),
              title: Text(
                tx.invoiceNo,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${formatDateTime(tx.createdAt)} • ${paymentMethodLabel(tx.paymentMethod)}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRupiah(tx.totalAmount),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  if (voided)
                    const Text(
                      'DIBATALKAN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                    ),
                ],
              ),
              onTap: () => _showDetail(tx),
            ),
          );
        },
      ),
    );
  }
}
