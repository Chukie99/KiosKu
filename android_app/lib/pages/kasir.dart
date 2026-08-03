import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../api.dart';
import '../components.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';
import 'payment_page.dart';
import 'products_page.dart';
import 'scan_page.dart';

class KasirPage extends ConsumerStatefulWidget {
  const KasirPage({super.key});

  @override
  ConsumerState<KasirPage> createState() => _KasirPageState();
}

class _KasirPageState extends ConsumerState<KasirPage> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _openScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
  }

  Future<void> _openProducts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PilihProdukPage()),
    );
  }

  Future<void> _openPayment() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang masih kosong')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PaymentPage()),
    );
  }

  Future<void> _showVoidSheet() async {
    final api = ref.read(apiProvider);
    TxPage page;
    try {
      page = await api.getTransactions(page: 1);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.offline ? 'Offline — riwayat tidak tersedia' : e.message)),
      );
      return;
    }
    if (!mounted) return;
    final recent = page.items.take(10).toList();
    if (recent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada transaksi')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Void Transaksi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: recent.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (_, index) {
                    final tx = recent[index];
                    return ListTile(
                      leading: const Icon(
                        LucideIcons.receipt,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        tx.invoiceNo,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(formatDateTime(tx.createdAt)),
                      trailing: Text(
                        formatRupiah(tx.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _confirmVoid(tx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmVoid(Transaction tx) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Void Transaksi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${tx.invoiceNo} — ${formatRupiah(tx.totalAmount)}'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Alasan void',
                  hintText: 'Contoh: salah input',
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
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
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
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final products = ref.watch(productsProvider).valueOrNull;
    final favorites =
        products?.where((p) => p.isFavorite).take(8).toList() ?? [];
    final total = cart.fold<double>(0, (sum, item) => sum + item.subtotal);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settings?.storeName ?? 'KiosKu',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              formatTime(_now),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Void transaksi',
            icon: const Icon(LucideIcons.trash2),
            onPressed: _showVoidSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: cart.isEmpty
                ? const _EmptyCart()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      return CartLineItem(
                        item: item,
                        onIncrease: () => ref
                            .read(cartProvider.notifier)
                            .changeQty(index, item.qty + 1),
                        onDecrease: () => ref
                            .read(cartProvider.notifier)
                            .changeQty(index, item.qty - 1),
                        onRemove: () =>
                            ref.read(cartProvider.notifier).remove(index),
                      );
                    },
                  ),
          ),
          if (favorites.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Favorit',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 116,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: favorites.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        final product = favorites[index];
                        return FavoriteQuickButton(
                          product: product,
                          onTap: () {
                            ref.read(cartProvider.notifier).add(CartItem(
                                  product: product,
                                  qty: 1,
                                  unitName: product.unitBase,
                                  pricePerUnit: product.priceSell,
                                ));
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 56),
                    ),
                    onPressed: _openScanner,
                    icon: const Icon(LucideIcons.scanLine),
                    label: const Text('Scan Barcode'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openProducts,
                    icon: const Icon(LucideIcons.package),
                    label: const Text('Pilih Produk'),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        formatRupiah(total),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 56,
                  width: 150,
                  child: FilledButton(
                    onPressed: cart.isEmpty ? null : _openPayment,
                    child: const Text('Bayar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.shoppingCart,
            size: 56,
            color: AppColors.border,
          ),
          SizedBox(height: 12),
          Text(
            'Belum ada barang, scan atau pilih produk',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
