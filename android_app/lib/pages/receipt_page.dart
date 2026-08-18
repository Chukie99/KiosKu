import 'dart:io';
import 'dart:typed_data';import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  Future<Uint8List> _buildPdfBytes() async {
    final tx = widget.tx;
    final doc = pw.Document();
    const money = PdfColor.fromInt(0xFF2A211C);
    const muted = PdfColor.fromInt(0xFF8A7A6B);
    const primary = PdfColor.fromInt(0xFFA8402E);

    String qtyLabel(double qty) =>
        qty == qty.roundToDouble() ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                widget.storeName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: primary,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                tx.invoiceNo,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 10, color: muted),
              ),
              pw.Text(
                formatDateTime(tx.createdAt),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 10, color: muted),
              ),
              pw.Text(
                'Metode: ${paymentMethodLabel(tx.paymentMethod)}',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 10, color: muted),
              ),
              if (widget.pending) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'MENUNGGU SINKRONISASI',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFFD97706),
                  ),
                ),
              ],
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.6, color: const PdfColor.fromInt(0xFFE8DCC8)),
              for (final item in tx.items) ...[
                pw.Text(
                  item.productNameSnapshot,
                  style: pw.TextStyle(fontSize: 10, color: money),
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${qtyLabel(item.qty == 0 ? 1 : item.qty)} x ${formatRupiah(item.pricePerUnit)}',
                      style: pw.TextStyle(fontSize: 9, color: muted),
                    ),
                    pw.Text(
                      formatRupiah(item.subtotal),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: money,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
              ],
              pw.Divider(thickness: 0.6, color: const PdfColor.fromInt(0xFFE8DCC8)),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: money,
                    ),
                  ),
                  pw.Text(
                    formatRupiah(tx.totalAmount),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: money,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tunai', style: pw.TextStyle(fontSize: 10, color: muted)),
                  pw.Text(
                    formatRupiah(tx.cashReceived),
                    style: pw.TextStyle(fontSize: 10, color: money),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Kembalian', style: pw.TextStyle(fontSize: 10, color: muted)),
                  pw.Text(
                    formatRupiah(tx.changeAmount),
                    style: pw.TextStyle(fontSize: 10, color: money),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                height: 1,
                margin: const pw.EdgeInsets.symmetric(horizontal: 40),
                color: muted,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Tanda tangan',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 8, color: muted),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 0.6, color: const PdfColor.fromInt(0xFFE8DCC8)),
              pw.SizedBox(height: 6),
              pw.Text(
                'Terima kasih atas kunjungan Anda!',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primary),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                widget.storeName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 9, color: muted),
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  Future<void> _printTicket() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      final bytes = await _buildPdfBytes();
      await Printing.layoutPdf(
        name: 'Struk ${widget.tx.invoiceNo}',
        format: PdfPageFormat.roll80,
        onLayout: (_) async => bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Struk berhasil dicetak')),
      );
    } catch (_) {
      if (!mounted) return;
      await _showPrintGuide('Gagal mencetak struk. Pastikan printer terpasang di Windows.');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _savePdf() async {
    try {
      final bytes = await _buildPdfBytes();
      final dir = Directory(
        '${Platform.environment['USERPROFILE'] ?? '.'}\\Documents\\KiosKu',
      );
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File(
        '${dir.path}\\struk_${widget.tx.invoiceNo.replaceAll('/', '-')}.pdf',
      );
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Struk tersimpan di ${file.path}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan struk')),
      );
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
            '1. Pastikan printer thermal/struk sudah terpasang di Windows (Printers & scanners).\n'
            '2. Saat dialog cetak muncul, pilih printer yang benar.\n'
            '3. Untuk printer thermal 80mm, gunakan kertas 80mm pada pengaturan printer.\n'
            '4. Coba lagi setelah printer siap.',
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
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          height: 1,
                          color: AppColors.textSecondary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tanda tangan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 6),
                        const Text(
                          'Terima kasih atas kunjungan Anda!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.storeName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
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
                      onPressed: _printing ? null : _savePdf,
                      icon: const Icon(LucideIcons.fileDown, size: 18),
                      label: const Text('Simpan PDF'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
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
                    child: OutlinedButton(
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
