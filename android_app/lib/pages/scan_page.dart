import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [],
  );

  bool _handling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handling) return;
    final raw = capture.barcodes
        .where((b) => b.rawValue != null && b.rawValue!.isNotEmpty)
        .map((b) => b.rawValue!)
        .toList();
    if (raw.isEmpty) return;
    _handling = true;
    HapticFeedback.mediumImpact();
    _processCode(raw.first, resetOnFail: true);
  }

  Future<void> _processCode(String code, {bool resetOnFail = false}) async {
    try {
      final db = ref.read(dbProvider);
      var product = await db.getProductByBarcode(code);
      if (product == null) {
        product = await ref.read(apiProvider).getProductByBarcode(code);
        if (product != null) {
          await db.upsertProduct(product);
        }
      }
      if (!mounted) return;
      if (product != null) {
        ref.read(cartProvider.notifier).add(CartItem(
              product: product,
              qty: 1,
              unitName: product.unitBase,
              pricePerUnit: product.priceSell,
            ));
        Navigator.of(context).pop();
      } else {
        _handling = false;
        await _showNotFoundDialog(code);
      }
    } on ApiException {
      _handling = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — tidak dapat memeriksa barcode')),
      );
      if (resetOnFail) {
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _handling = false);
        });
      }
    }
  }

  Future<void> _showNotFoundDialog(String code) async {
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Barcode tidak ditemukan'),
          content: Text('Kode "$code" tidak terdaftar di produk.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'retry'),
              child: const Text('Coba Lagi'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'add'),
              child: const Text('Tambah Produk Baru'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (action == 'add') {
      await _showAddProductDialog(code);
    }
  }

  Future<void> _showAddProductDialog(String barcode) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    int? selectedCategoryId;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah Produk Baru'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama produk',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga jual',
                        prefixText: 'Rp ',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: TextEditingController(text: barcode),
                      enabled: false,
                      decoration: const InputDecoration(labelText: 'Barcode'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      hint: const Text('Pilih kategori'),
                      items: categories
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedCategoryId = value);
                      },
                    ),
                  ],
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
    final price = double.tryParse(priceController.text.trim());
    if (name.isEmpty || price == null || price <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan harga harus diisi')),
      );
      return;
    }
    try {
      final product = await ref.read(apiProvider).addProduct(
            name: name,
            priceSell: price,
            categoryId: selectedCategoryId,
            barcode: barcode,
          );
      await ref.read(dbProvider).upsertProduct(product);
      ref.read(productsProvider.notifier).refresh();
      if (!mounted) return;
      ref.read(cartProvider.notifier).add(CartItem(
            product: product,
            qty: 1,
            unitName: product.unitBase,
            pricePerUnit: product.priceSell,
          ));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.offline ? 'Offline — tidak dapat menambah produk' : e.message)),
      );
    }
  }

  Future<void> _showManualInput() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Input Manual'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: 'Kode barcode / SKU',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Cari'),
            ),
          ],
        );
      },
    );
    if (code == null || code.isEmpty) return;
    await _processCode(code, resetOnFail: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.camera,
                      size: 48,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tidak dapat mengakses kamera',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => _controller.start(),
                      child: const Text('Minta Izin'),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        LucideIcons.arrowLeft,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                      onPressed: () => _controller.toggleTorch(),
                      icon: const Icon(
                        LucideIcons.camera,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                      onPressed: _showManualInput,
                      icon: const Icon(
                        LucideIcons.keyRound,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: Column(
              children: [
                const Text(
                  'Arahkan kamera ke barcode produk',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    backgroundColor: Colors.black45,
                  ),
                  onPressed: _showManualInput,
                  icon: const Icon(LucideIcons.keyRound, size: 16),
                  label: const Text('Input Manual'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
