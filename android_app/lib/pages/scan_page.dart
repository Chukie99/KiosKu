import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _buffer = [];
  Timer? _bufferTimer;

  bool _handling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _bufferTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_handling) return;
    final key = event.logicalKey;
    if (event.character != null && event.character!.isNotEmpty) {
      _buffer.add(event.character!);
    } else if (key == LogicalKeyboardKey.enter) {
      _flushBuffer();
    } else if (key == LogicalKeyboardKey.backspace && _buffer.isNotEmpty) {
      _buffer.removeLast();
    }
    _bufferTimer?.cancel();
    _bufferTimer = Timer(const Duration(milliseconds: 80), _flushBuffer);
  }

  void _flushBuffer() {
    _bufferTimer?.cancel();
    _bufferTimer = null;
    if (_buffer.isEmpty) return;
    final code = _buffer.join().trim();
    _buffer.clear();
    if (code.isEmpty) return;
    _handling = true;
    HapticFeedback.mediumImpact();
    _processCode(code, resetOnFail: true);
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
      backgroundColor: AppColors.primary,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      LucideIcons.qrCode,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Siap Scan Barcode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Arahkan scanner USB ke barcode produk, atau ketik kode di bawah lalu tekan Enter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 320,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      onSubmitted: (value) {
                        if (value.trim().isEmpty) return;
                        _controller.clear();
                        _handling = true;
                        _processCode(value.trim(), resetOnFail: true);
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Ketik kode barcode / SKU...',
                        icon: Icon(
                          LucideIcons.scan,
                          color: AppColors.primary,
                        ),
                      ),
                      textInputAction: TextInputAction.go,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _showManualInput,
                    icon: const Icon(LucideIcons.keyRound, size: 18),
                    label: const Text('Buka Dialog Input Manual'),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              top: 16,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black26,
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  LucideIcons.arrowLeft,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
