import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../components.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';

class PilihProdukPage extends ConsumerStatefulWidget {
  const PilihProdukPage({super.key});

  @override
  ConsumerState<PilihProdukPage> createState() => _PilihProdukPageState();
}

class _PilihProdukPageState extends ConsumerState<PilihProdukPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(productsProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  Future<void> _addToCart(Product product) async {
    if (product.units.isNotEmpty && product.units.length > 1) {
      final unit = await _pickUnit(product);
      if (unit == null) return;
      await _pickQty(product, unit.unitName, unit.priceSell);
    } else {
      await _pickQty(product, product.unitBase, product.priceSell);
    }
  }

  Future<ProductUnit?> _pickUnit(Product product) async {
    return showModalBottomSheet<ProductUnit>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Pilih Satuan — ${product.name}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              for (final unit in product.units)
                ListTile(
                  title: Text(unit.unitName),
                  subtitle: Text(
                    '1 ${product.unitBase} = ${_cleanQty(unit.conversionQty)} ${unit.unitName}',
                  ),
                  trailing: Text(
                    formatRupiah(unit.priceSell),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  onTap: () => Navigator.pop(sheetContext, unit),
                ),
            ],
          ),
        );
      },
    );
  }

  String _cleanQty(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  Future<void> _pickQty(
    Product product,
    String unitName,
    double pricePerUnit,
  ) async {
    var qtyText = '1';
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final qty = double.tryParse(qtyText) ?? 0;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$unitName — ${formatRupiah(pricePerUnit)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      qtyText,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Subtotal ${formatRupiah(qty * pricePerUnit)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    NumericKeypad(
                      onKey: (key) {
                        setSheetState(() {
                          if (key == 'backspace') {
                            qtyText = qtyText.length > 1
                                ? qtyText.substring(0, qtyText.length - 1)
                                : '0';
                          } else if (key == '.') {
                            if (!qtyText.contains('.')) qtyText = '$qtyText.';
                          } else {
                            if (qtyText == '0') {
                              qtyText = key;
                            } else if (qtyText.length < 8) {
                              qtyText = '$qtyText$key';
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: qty <= 0
                            ? null
                            : () => Navigator.pop(sheetContext, true),
                        child: const Text('Tambah ke Keranjang'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (confirmed != true) return;
    final qty = double.tryParse(qtyText) ?? 0;
    if (qty <= 0) return;
    ref.read(cartProvider.notifier).add(CartItem(
          product: product,
          qty: qty,
          unitName: unitName,
          pricePerUnit: pricePerUnit,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? [];
    final products = productsAsync.valueOrNull ?? [];

    final filtered = products.where((p) {
      final matchCategory = _selectedCategory == null ||
          p.categoryId == _selectedCategory;
      final q = _query.toLowerCase();
      final matchQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.barcode.toLowerCase().contains(q);
      return matchCategory && matchQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Produk')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Cari produk atau barcode...',
                prefixIcon: Icon(LucideIcons.search, size: 20),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                CategoryChip(
                  label: 'Semua',
                  selected: _selectedCategory == null,
                  onTap: () => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                for (final category in categories) ...[
                  CategoryChip(
                    label: category.name,
                    selected: _selectedCategory == category.id,
                    onTap: () =>
                        setState(() => _selectedCategory = category.id),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: productsAsync.when(
              loading: () => GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: _gridDelegate,
                itemCount: 8,
                itemBuilder: (context, index) =>
                    const SkeletonBox(height: double.infinity, radius: 12),
              ),
              error: (error, _) => _ErrorRetry(
                message: 'Gagal memuat produk',
                onRetry: () =>
                    ref.read(productsProvider.notifier).refresh(),
              ),
              data: (_) {
                if (filtered.isEmpty) {
                  return const _EmptyProducts();
                }
                return GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: _gridDelegate,
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index >= filtered.length) {
                      return ref.read(productsProvider.notifier).hasMore
                          ? const SkeletonBox(
                              height: double.infinity, radius: 12)
                          : const SizedBox.shrink();
                    }
                    final product = filtered[index];
                    return ProductGridCard(
                      product: product,
                      showFavorite: true,
                      onTap: () => _addToCart(product),
                      onFavoriteTap: () => ref
                          .read(productsProvider.notifier)
                          .toggleFavorite(product),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  SliverGridDelegateWithFixedCrossAxisCount get _gridDelegate {
    return const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.78,
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: const TextStyle(
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

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Produk tidak ditemukan',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
