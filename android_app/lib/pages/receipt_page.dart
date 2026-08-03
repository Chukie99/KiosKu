import 'dart:typed_data';

import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_usb_printer/flutter_usb_printer.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../components.dart';
import '../models.dart';
import '../theme.dart';

class ReceiptPage extends StatefulWidget {
  final Transaction tx;
  final String storeName;
  final bool pending;

  const ReceiptPage({
    super.key,
    required this.tx,
    required this.storeName,
    this.pending = false,
  });

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  bool _printing = false;

  Future<List<int>> _buildTicketBytes() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final tx = widget.tx;
    List<int> bytes = [];
    bytes += generator.text(
      widget.storeName,
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      tx.invoiceNo,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      formatDateTime(tx.createdAt),
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text('Metode: ${paymentMethodLabel(tx.paymentMethod)}',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);
    bytes += generator.text('-' * 32);
    for (final item in tx.items) {
      bytes += generator.text(item.productNameSnapshot);
      final qtyLabel = item.qty == item.qty.roundToDouble()
          ? item.qty.toStringAsFixed(0)
          : item.qty.toStringAsFixed(2);
      bytes += generator.text('${item.qty == 0 ? '1' : qtyLabel} x '
          '${formatRupiah(item.pricePerUnit)}'
          '${' ' * 8}${formatRupiah(item.subtotal)}');
    }
    bytes += generator.text('-' * 32);
    bytes += generator.text(
      'TOTAL',
      styles: const PosStyles(bold: true),
    );
    bytes += generator.text(
      formatRupiah(tx.totalAmount),
      styles: const PosStyles(bold: true, align: PosAlign.right),
    );
    bytes += generator.feed(1);
    bytes += generator.text(
      'Tunai: ${formatRupiah(tx.cashReceived)}',
      styles: const PosStyles(align: PosAlign.right),
    );
    bytes += generator.text(
      'Kembalian: ${formatRupiah(tx.changeAmount)}',
      styles: const PosStyles(align: PosAlign.right),
    );
    bytes += generator.feed(1);
    bytes += generator.text(
      widget.pending ? 'MENUNGGU SINKRONISASI' : 'Terima kasih!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.feed(3);
    bytes += generator.cut();
    return bytes;
  }

  Future<void> _printTicket() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (sheetContext) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Cetak Struk',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    LucideIcons.bluetooth,
                    color: AppColors.primary,
                  ),
                  title: const Text('Printer Bluetooth'),
                  onTap: () => Navigator.pop(sheetContext, 'bluetooth'),
                ),
                ListTile(
                  leading: const Icon(
                    LucideIcons.usb,
                    color: AppColors.primary,
                  ),
                  title: const Text('Printer USB'),
                  onTap: () => Navigator.pop(sheetContext, 'usb'),
                ),
              ],
            ),
          );
        },
      );
      if (action == null) return;
      final bytes = await _buildTicketBytes();
      if (action == 'bluetooth') {
        await _printBluetooth(bytes);
      } else {
        await _printUsb(bytes);
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _printBluetooth(List<int> bytes) async {
    final manager = PrinterBluetoothManager();
    List<PrinterBluetooth> devices = [];
    manager.scanResults.listen((results) => devices = results);
    manager.startScan(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    if (devices.isEmpty) {
      await _showPrintGuide('Tidak ada printer Bluetooth ditemukan.');
      return;
    }
    final selected = await showDialog<PrinterBluetooth>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Pilih Printer Bluetooth'),
          children: [
            for (final device in devices)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, device),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(device.name ?? 'Printer'),
                  subtitle: Text(device.address ?? ''),
                ),
              ),
          ],
        );
      },
    );
    if (selected == null) return;
    if (!mounted) return;
    try {
      manager.selectPrinter(selected);
      final result = await manager.printTicket(bytes);
      if (!mounted) return;
      if (result == PosPrintResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Struk berhasil dicetak')),
        );
      } else {
        await _showPrintGuide('Gagal mencetak: ${result.msg}');
      }
    } catch (_) {
      if (!mounted) return;
      await _showPrintGuide('Gagal terhubung ke printer Bluetooth.');
    }
  }

  Future<void> _printUsb(List<int> bytes) async {
    try {
      final devices = await FlutterUsbPrinter.getUSBDeviceList();
      if (!mounted) return;
      if (devices.isEmpty) {
        await _showPrintGuide('Tidak ada printer USB terhubung.');
        return;
      }
      Map<String, dynamic>? selected;
      if (devices.length == 1) {
        selected = devices.first;
      } else {
        selected = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (dialogContext) {
            return SimpleDialog(
              title: const Text('Pilih Printer USB'),
              children: [
                for (final device in devices)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(dialogContext, device),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${device['deviceName'] ?? 'Printer'}'),
                      subtitle: Text(
                        'Vendor ${device['vendorId']} — '
                        'Product ${device['productId']}',
                      ),
                    ),
                  ),
              ],
            );
          },
        );
        if (selected == null) return;
      }
      if (!mounted) return;
      final printer = FlutterUsbPrinter();
      final ok = await printer.connect(
        int.parse('${selected['vendorId'] ?? '0'}'),
        int.parse('${selected['productId'] ?? '0'}'),
      );
      if (ok == true) {
        await printer.write(Uint8List.fromList(bytes));
        await printer.close();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Struk berhasil dicetak')),
        );
      } else {
        if (!mounted) return;
        await _showPrintGuide('Gagal terhubung ke printer USB.');
      }
    } catch (_) {
      if (!mounted) return;
      await _showPrintGuide('Gagal mencetak melalui USB.');
    }
  }

  Future<void> _showPrintGuide(String title) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: const Text(
            'Panduan:\n'
            '1. Nyalakan printer dan pastikan baterai/adaptor cukup.\n'
            '2. Untuk Bluetooth: aktifkan Bluetooth perangkat dan printer, lalu pasangkan.\n'
            '3. Untuk USB: sambungkan printer ke perangkat dengan kabel OTG.\n'
            '4. Buka Pengaturan > server dan pastikan printer terlihat, lalu coba lagi.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Mengerti'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Struk Transaksi'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.pending) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'MENUNGGU SINKRONISASI',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          widget.storeName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tx.invoiceNo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          formatDateTime(tx.createdAt),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Metode: ${paymentMethodLabel(tx.paymentMethod)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Divider(),
                        for (final item in tx.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productNameSnapshot,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${item.qty == 0 ? 1 : item.qty.toStringAsFixed(0)} x ${formatRupiah(item.pricePerUnit)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      formatRupiah(item.subtotal),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        const Divider(),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              formatRupiah(tx.totalAmount),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _ReceiptLine(
                          label: 'Tunai',
                          value: formatRupiah(tx.cashReceived),
                        ),
                        _ReceiptLine(
                          label: 'Kembalian',
                          value: formatRupiah(tx.changeAmount),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Terima kasih!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _printing ? null : _printTicket,
                      icon: _printing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(LucideIcons.printer, size: 18),
                      label: const Text('Cetak Struk'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Selesai'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
