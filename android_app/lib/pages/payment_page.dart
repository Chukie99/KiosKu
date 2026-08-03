import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../api.dart';
import '../components.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';
import 'receipt_page.dart';

class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key});

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  String _method = 'tunai';
  String _cashText = '';
  bool _qrConfirmed = false;
  int _activeSplitRow = 0;
  String _splitMethodA = 'tunai';
  String _splitMethodB = 'qris';
  String _splitAmountA = '';
  String _splitAmountB = '';
  Customer? _customer;
  DateTime? _dueDate;
  bool _saving = false;

  double get _total {
    return ref
        .read(cartProvider)
        .fold<double>(0, (sum, item) => sum + item.subtotal);
  }

  double get _cashValue => double.tryParse(_cashText) ?? 0;

  double get _change => _cashValue - _total;

  void _onCashKey(String key) {
    setState(() {
      if (key == 'backspace') {
        if (_cashText.isNotEmpty) {
          _cashText = _cashText.substring(0, _cashText.length - 1);
        }
      } else if (key == '.') {
        if (!_cashText.contains('.')) {
          _cashText = _cashText.isEmpty ? '0.' : '$_cashText.';
        }
      } else {
        if (_cashText == '0') {
          _cashText = key;
        } else if (_cashText.length < 10) {
          _cashText += key;
        }
      }
    });
  }

  void _onSplitKey(String key) {
    setState(() {
      final text =
          _activeSplitRow == 0 ? _splitAmountA : _splitAmountB;
      String updated;
      if (key == 'backspace') {
        updated = text.length > 1
            ? text.substring(0, text.length - 1)
            : '';
      } else if (key == '.') {
        if (!text.contains('.')) {
          updated = text.isEmpty ? '0.' : '$text.';
        } else {
          updated = text;
        }
      } else {
        if (text == '0') {
          updated = key;
        } else if (text.length < 10) {
          updated = '$text$key';
        } else {
          updated = text;
        }
      }
      if (_activeSplitRow == 0) {
        _splitAmountA = updated;
      } else {
        _splitAmountB = updated;
      }
    });
  }

  double get _splitTotal {
    return (double.tryParse(_splitAmountA) ?? 0) +
        (double.tryParse(_splitAmountB) ?? 0);
  }

  Future<void> _selectCustomer() async {
    final api = ref.read(apiProvider);
    List<Customer> customers = [];
    try {
      customers = await api.getCustomers();
    } on ApiException {
      customers = await ref.read(dbProvider).getCustomers();
    }
    if (!mounted) return;
    final selected = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final searchController = TextEditingController();
            var results = customers;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Pilih Pelanggan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      onChanged: (value) {
                        setSheetState(() {
                          final q = value.toLowerCase();
                          results = customers
                              .where((c) =>
                                  c.name.toLowerCase().contains(q) ||
                                  c.phone.toLowerCase().contains(q))
                              .toList();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Cari pelanggan...',
                        prefixIcon: Icon(LucideIcons.search, size: 20),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final customer in results)
                            ListTile(
                              title: Text(customer.name),
                              subtitle: Text(customer.phone),
                              onTap: () =>
                                  Navigator.pop(sheetContext, customer),
                            ),
                          ListTile(
                            leading: const Icon(
                              LucideIcons.userPlus,
                              color: AppColors.primary,
                            ),
                            title: const Text('Tambah Pelanggan Baru'),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _addCustomer();
                            },
                          ),
                        ],
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
    if (selected != null) {
      await ref.read(dbProvider).upsertCustomers([selected]);
      if (mounted) setState(() => _customer = selected);
    }
  }

  Future<void> _addCustomer() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tambah Pelanggan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'No. HP'),
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
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    try {
      final customer = await ref
          .read(apiProvider)
          .addCustomer(name: name, phone: phoneController.text.trim());
      await ref.read(dbProvider).upsertCustomers([customer]);
      if (!mounted) return;
      setState(() => _customer = customer);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _pickDueDate() async {
    final initial = _dueDate ?? DateTime.now().add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _confirmQrPaid() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Pembayaran'),
          content: const Text(
            'Sudah cek manual bahwa pembayaran diterima?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Belum'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Tandai Lunas'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      setState(() => _qrConfirmed = true);
    }
  }

  bool get _canSave {
    switch (_method) {
      case 'tunai':
        return _cashValue >= _total;
      case 'qris':
      case 'ewallet':
        return _qrConfirmed;
      case 'split':
        return _splitTotal == _total &&
            _splitMethodA != _splitMethodB &&
            _splitTotal > 0;
      case 'utang':
        return _customer != null && _dueDate != null;
      default:
        return false;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final cart = ref.read(cartProvider);
    final api = ref.read(apiProvider);
    final db = ref.read(dbProvider);
    final deviceId = await getDeviceId();

    double? cashReceived;
    List<PaymentSplit>? split;
    String? dueDate;
    switch (_method) {
      case 'tunai':
        cashReceived = _cashValue;
        break;
      case 'qris':
      case 'ewallet':
        cashReceived = _total;
        break;
      case 'split':
        cashReceived = _total;
        split = [
          PaymentSplit(method: _splitMethodA, amount: double.parse(_splitAmountA)),
          PaymentSplit(method: _splitMethodB, amount: double.parse(_splitAmountB)),
        ];
        break;
      case 'utang':
        dueDate = '${_dueDate!.year.toString().padLeft(4, '0')}-'
            '${_dueDate!.month.toString().padLeft(2, '0')}-'
            '${_dueDate!.day.toString().padLeft(2, '0')}';
        break;
    }

    final payload = buildTransactionPayload(
      items: cart,
      paymentMethod: _method,
      cashReceived: cashReceived,
      customerId: _customer?.id,
      paymentSplit: split,
      dueDate: dueDate,
      deviceId: deviceId,
    );

    try {
      final tx = await api.createTransaction(
        items: cart,
        paymentMethod: _method,
        cashReceived: cashReceived,
        customerId: _customer?.id,
        paymentSplit: split,
        dueDate: dueDate,
        deviceId: deviceId,
      );
      await _goReceipt(tx, pending: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.offline) {
        await db.insertPendingTransaction(payload);
        final localTx = localTransactionFromPayload(payload);
        if (!mounted) return;
        await _goReceipt(localTx, pending: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _goReceipt(Transaction tx, {required bool pending}) async {
    final storeName =
        ref.read(settingsProvider).valueOrNull?.storeName ?? 'KiosKu';
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptPage(tx: tx, storeName: storeName, pending: pending),
      ),
    );
    if (!mounted) return;
    ref.read(cartProvider.notifier).clear();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.read(cartProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${cart.length} item',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatRupiah(_total),
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Metode Pembayaran',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    PaymentMethodSelector(
                      selected: _method,
                      onSelected: (method) => setState(() {
                        _method = method;
                        _qrConfirmed = false;
                      }),
                    ),
                    const SizedBox(height: 20),
                    if (_method == 'tunai') _buildCashSection(),
                    if (_method == 'qris' || _method == 'ewallet')
                      _buildQrSection(),
                    if (_method == 'split') _buildSplitSection(),
                    if (_method == 'utang') _buildDebtSection(),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave && !_saving ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan Transaksi'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Uang Diterima',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _cashText.isEmpty ? '0' : _cashText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: (_change < 0 ? AppColors.danger : AppColors.success)
                    .withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              ),
              child: Text(
                _change < 0
                    ? 'Kurang ${formatRupiah(-_change)}'
                    : 'Kembalian ${formatRupiah(_change)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _change < 0 ? AppColors.danger : AppColors.success,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _QuickCashChip(label: 'Uang Pas', onTap: _setExact),
                _QuickCashChip(label: '10rb', onTap: () => _setCash(10000)),
                _QuickCashChip(label: '20rb', onTap: () => _setCash(20000)),
                _QuickCashChip(label: '50rb', onTap: () => _setCash(50000)),
                _QuickCashChip(label: '100rb', onTap: () => _setCash(100000)),
              ],
            ),
            const SizedBox(height: 8),
            NumericKeypad(onKey: _onCashKey),
          ],
        ),
      ),
    );
  }

  void _setCash(num value) {
    setState(() => _cashText = value.toStringAsFixed(0));
  }

  void _setExact() {
    setState(() => _cashText = _total.toStringAsFixed(0));
  }

  Widget _buildQrSection() {
    final label = _method == 'qris' ? 'QRIS' : 'E-Wallet';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              paymentMethodIcon(_method),
              size: 44,
              color: AppColors.primary,
            ),
            const SizedBox(height: 10),
            Text(
              'Total ${formatRupiah(_total)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Minta pelanggan membayar melalui $label',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            if (_qrConfirmed)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.check, size: 18, color: AppColors.success),
                    SizedBox(width: 6),
                    Text(
                      'Pembayaran ditandai lunas',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _confirmQrPaid,
                icon: const Icon(LucideIcons.check, size: 18),
                label: const Text('Sudah Cek Manual? Tandai Lunas'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SplitRow(
              title: 'Metode 1',
              method: _splitMethodA,
              amount: _splitAmountA,
              active: _activeSplitRow == 0,
              onMethodChanged: (method) =>
                  setState(() => _splitMethodA = method),
              onTap: () => setState(() => _activeSplitRow = 0),
            ),
            const SizedBox(height: 12),
            _SplitRow(
              title: 'Metode 2',
              method: _splitMethodB,
              amount: _splitAmountB,
              active: _activeSplitRow == 1,
              onMethodChanged: (method) =>
                  setState(() => _splitMethodB = method),
              onTap: () => setState(() => _activeSplitRow = 1),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_splitTotal == _total && _splitTotal > 0
                        ? AppColors.success
                        : AppColors.warning)
                    .withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              ),
              child: Text(
                _splitTotal == _total && _splitTotal > 0
                    ? 'Total pembagian pas: ${formatRupiah(_splitTotal)}'
                    : 'Total pembagian: ${formatRupiah(_splitTotal)} (target ${formatRupiah(_total)})',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _splitTotal == _total && _splitTotal > 0
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
            ),
            const SizedBox(height: 8),
            NumericKeypad(onKey: _onSplitKey),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                LucideIcons.users,
                color: AppColors.primary,
              ),
              title: Text(
                _customer?.name ?? 'Pilih Pelanggan',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(_customer?.phone ?? 'Pelanggan diutangkan'),
              trailing: OutlinedButton(
                onPressed: _selectCustomer,
                child: Text(_customer == null ? 'Pilih' : 'Ganti'),
              ),
              onTap: _selectCustomer,
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                LucideIcons.calendarDays,
                color: AppColors.primary,
              ),
              title: Text(
                _dueDate == null
                    ? 'Pilih Tanggal Jatuh Tempo'
                    : 'Jatuh tempo: ${formatDate(_dueDate!.toIso8601String())}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              trailing: OutlinedButton(
                onPressed: _pickDueDate,
                child: Text(_dueDate == null ? 'Pilih' : 'Ubah'),
              ),
              onTap: _pickDueDate,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCashChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickCashChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  final String title;
  final String method;
  final String amount;
  final bool active;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback onTap;

  const _SplitRow({
    required this.title,
    required this.method,
    required this.amount,
    required this.active,
    required this.onMethodChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withOpacity(0.06)
              : AppColors.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: active ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    value: method,
                    isExpanded: false,
                    underline: const SizedBox.shrink(),
                    items: PaymentMethodSelector.methods
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                paymentMethodLabel(m),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onMethodChanged(value);
                    },
                  ),
                ],
              ),
            ),
            Text(
              amount.isEmpty ? '0' : amount,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
