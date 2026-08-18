import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../api.dart';
import '../../components.dart';
import '../../models.dart';
import '../../providers.dart';
import '../../theme.dart';
import 'owner_components.dart';

class OwnerProductsPage extends ConsumerStatefulWidget {
  const OwnerProductsPage({super.key});

  @override
  ConsumerState<OwnerProductsPage> createState() => _OwnerProductsPageState();
}

class _OwnerProductsPageState extends ConsumerState<OwnerProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _page = 1;
  final int _pageSize = 50;
  int _total = 0;
  int? _categoryId;
  bool _loading = false;
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(categoriesProvider);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiProvider);
      final q = _searchController.text.trim();
      List<Product> items;
      int total;
      if (q.isNotEmpty) {
        items = await api.searchProducts(q);
        total = items.length;
      } else {
        final page = await api.getProducts(
          page: _page,
          pageSize: _pageSize,
          categoryId: _categoryId,
          includeInactive: true,
        );
        items = page.items;
        total = page.total;
      }
      if (!mounted) return;
      setState(() {
        _products = items;
        _total = total;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.offline ? 'Offline — produk tidak dapat dimuat' : e.message),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _page = 1;
      _load();
    });
  }

  Future<void> _openCategoryDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tambah Kategori'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nama kategori'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(apiProvider).addCategory(name);
      ref.invalidate(categoriesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori ditambahkan')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _openProductDialog({Product? product}) async {
    final isEdit = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final barcodeController =
        TextEditingController(text: product?.barcode ?? product?.sku ?? '');
    final buyController =
        TextEditingController(text: (product?.priceBuy ?? 0).toString());
    final sellController =
        TextEditingController(text: (product?.priceSell ?? 0).toString());
    final stockController =
        TextEditingController(text: (product?.stock ?? 0).toString());
    final thresholdController = TextEditingController(
      text: (product?.stockAlertThreshold ?? 5).toString(),
    );
    final unitController =
        TextEditingController(text: product?.unitBase ?? 'pcs');
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    int? categoryId = product?.categoryId;
    bool favorite = product?.isFavorite ?? false;
    String? photoPath;
    final picker = ImagePicker();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Produk' : 'Tambah Produk'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final xFile = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 800,
                            maxHeight: 800,
                            imageQuality: 80,
                          );
                          if (xFile != null) {
                            setDialogState(() => photoPath = xFile.path);
                          }
                        },
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: photoPath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    File(photoPath!),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.camera,
                                      size: 28,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Foto',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama produk *',
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        value: categoryId,
                        decoration: const InputDecoration(labelText: 'Kategori'),
                        hint: const Text('Pilih kategori'),
                        items: [
                          for (final c in categories)
                            DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => categoryId = value),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: barcodeController,
                        decoration: const InputDecoration(
                          labelText: 'Barcode / SKU',
                          hintText: 'Kosongkan untuk auto-generate',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: unitController,
                        decoration: const InputDecoration(
                          labelText: 'Satuan dasar',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: buyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Harga beli',
                                prefixText: 'Rp ',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: sellController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Harga jual *',
                                prefixText: 'Rp ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: stockController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Stok awal',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: thresholdController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Ambang alert stok',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: favorite,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Tandai sebagai produk favorit'),
                        onChanged: (value) =>
                            setDialogState(() => favorite = value ?? false),
                      ),
                    ],
                  ),
                ),
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
      },
    );
    if (submitted != true) return;
    final name = nameController.text.trim();
    final priceSell = double.tryParse(sellController.text.trim());
    if (name.isEmpty || priceSell == null || priceSell <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan harga jual harus diisi')),
      );
      return;
    }
    final payload = <String, dynamic>{
      'name': name,
      'category_id': categoryId,
      'barcode': barcodeController.text.trim().isEmpty
          ? null
          : barcodeController.text.trim(),
      'unit_base': unitController.text.trim().isEmpty
          ? 'pcs'
          : unitController.text.trim(),
      'price_buy': double.tryParse(buyController.text.trim()) ?? 0,
      'price_sell': priceSell,
      'stock': double.tryParse(stockController.text.trim()) ?? 0,
      'stock_alert_threshold':
          double.tryParse(thresholdController.text.trim()) ?? 5,
      'is_favorite': favorite,
      'is_active': product?.isActive ?? true,
    };
    try {
      final api = ref.read(apiProvider);
      if (isEdit) {
        await api.updateProduct(product.id, payload);
        if (photoPath != null) {
          await api.uploadProductPhoto(product.id, photoPath!);
        }
      } else {
        final newProduct = await api.addProduct(
          name: name,
          priceSell: priceSell,
          categoryId: categoryId,
          barcode: barcodeController.text.trim().isEmpty
              ? null
              : barcodeController.text.trim(),
        );
        if (photoPath != null) {
          await api.uploadProductPhoto(newProduct.id, photoPath!);
        }
      }
      ref.read(productsProvider.notifier).refresh();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Produk diperbarui' : 'Produk ditambahkan')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _toggleFavorite(Product product) async {
    try {
      await ref.read(apiProvider).updateProduct(product.id, {
        ...product.toJson(),
        'is_favorite': !product.isFavorite,
      });
      ref.read(productsProvider.notifier).refresh();
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nonaktifkan Produk'),
          content: Text(
            'Produk "${product.name}" akan dinonaktifkan (tidak dihapus permanen). Lanjutkan?',
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
              child: const Text('Nonaktifkan'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiProvider).deleteProduct(product.id);
      ref.read(productsProvider.notifier).refresh();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk dinonaktifkan')),
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
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final pageCount = (_total / _pageSize).ceil().clamp(1, 999999999);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Tambah Kategori',
            icon: const Icon(LucideIcons.tags),
            onPressed: _openCategoryDialog,
          ),
          IconButton(
            tooltip: 'Tambah Produk',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _openProductDialog(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Cari produk...',
                      prefixIcon: Icon(LucideIcons.search, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int?>(
                    value: _categoryId,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Semua Kategori'),
                      ),
                      for (final c in categories)
                        DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.name),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => _categoryId = value);
                      _page = 1;
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(LucideIcons.refreshCcw, size: 18),
                  label: const Text('Muat Ulang'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada produk. Tambahkan produk pertama.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Produk')),
                                    DataColumn(label: Text('Kategori')),
                                    DataColumn(label: Text('Satuan')),
                                    DataColumn(
                                      label: Text('Harga Beli'),
                                      numeric: true,
                                    ),
                                    DataColumn(
                                      label: Text('Harga Jual'),
                                      numeric: true,
                                    ),
                                    DataColumn(label: Text('Stok')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Aksi')),
                                  ],
                                  rows: [
                                    for (final product in _products)
                                      DataRow(
                                        cells: [
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  LucideIcons.package,
                                                  size: 16,
                                                  color: AppColors.primary,
                                                ),
                                                const SizedBox(width: 8),
                                                ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(
                                                    maxWidth: 220,
                                                  ),
                                                  child: Text(
                                                    product.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            Text(product.categoryName ?? '-'),
                                          ),
                                          DataCell(Text(product.unitBase)),
                                          DataCell(
                                            Text(formatRupiah(product.priceBuy)),
                                          ),
                                          DataCell(
                                            Text(formatRupiah(product.priceSell)),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 110,
                                              child: StatusBadge(
                                                text:
                                                    'Stok ${product.stock.toStringAsFixed(0)}',
                                                color: stockStatusColor(
                                                  product.stock,
                                                  product.stockAlertThreshold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            StatusBadge(
                                              text: product.isActive
                                                  ? 'Aktif'
                                                  : 'Nonaktif',
                                              color: product.isActive
                                                  ? AppColors.success
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  tooltip: 'Favorit',
                                                  icon: Icon(
                                                    product.isFavorite
                                                        ? LucideIcons.star
                                                        : LucideIcons.star,
                                                    size: 18,
                                                    color: product.isFavorite
                                                        ? AppColors.warning
                                                        : AppColors.border,
                                                  ),
                                                  onPressed: () =>
                                                      _toggleFavorite(product),
                                                ),
                                                IconButton(
                                                  tooltip: 'Edit',
                                                  icon: const Icon(
                                                    LucideIcons.pencil,
                                                    size: 18,
                                                  ),
                                                  onPressed: () =>
                                                      _openProductDialog(
                                                        product: product,
                                                      ),
                                                ),
                                                IconButton(
                                                  tooltip: 'Nonaktifkan',
                                                  icon: const Icon(
                                                    LucideIcons.trash2,
                                                    size: 18,
                                                    color: AppColors.danger,
                                                  ),
                                                  onPressed: () =>
                                                      _deleteProduct(product),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_searchController.text.trim().isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      LucideIcons.chevronLeft,
                                      size: 20,
                                    ),
                                    onPressed: _page > 1
                                        ? () {
                                            setState(() => _page--);
                                            _load();
                                          }
                                        : null,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'Halaman $_page dari $pageCount '
                                      '(${_total} produk)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _page < pageCount
                                        ? () {
                                            setState(() => _page++);
                                            _load();
                                          }
                                        : null,
                                    icon: const Icon(
                                      LucideIcons.chevronRight,
                                      size: 20,
                                    ),
                                  ),
                                ],
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