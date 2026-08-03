import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'models.dart';
import 'providers.dart';
import 'theme.dart';

String formatRupiah(num value) {
  return NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  ).format(value);
}

String formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return DateFormat('dd/MM/yyyy HH:mm').format(dt);
}

String formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return DateFormat('dd/MM/yyyy').format(dt);
}

String formatTime(DateTime dt) => DateFormat('HH:mm:ss').format(dt);

String paymentMethodLabel(String method) {
  switch (method) {
    case 'qris':
      return 'QRIS';
    case 'ewallet':
      return 'E-Wallet';
    case 'split':
      return 'Split';
    case 'utang':
      return 'Utang';
    case 'tunai':
    default:
      return 'Tunai';
  }
}

IconData paymentMethodIcon(String method) {
  switch (method) {
    case 'qris':
      return LucideIcons.qrCode;
    case 'ewallet':
      return LucideIcons.smartphone;
    case 'split':
      return LucideIcons.wallet;
    case 'utang':
      return LucideIcons.receipt;
    case 'tunai':
    default:
      return LucideIcons.banknote;
  }
}

class NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final bool showDecimal;

  const NumericKeypad({
    super.key,
    required this.onKey,
    this.showDecimal = true,
  });

  @override
  Widget build(BuildContext context) {
    final labels = <String>['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    if (showDecimal) labels.add('.');
    labels.addAll(['0', 'backspace']);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 4; row++)
          Row(
            children: [
              for (var col = 0; col < 3; col++)
                Expanded(child: _KeypadButton(
                  label: labels[row * 3 + col],
                  onTap: () => onKey(labels[row * 3 + col]),
                )),
            ],
          ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KeypadButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: label == 'backspace' ? AppColors.background : AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: SizedBox(
            height: 56,
            child: Center(
              child: label == 'backspace'
                  ? const Icon(
                      LucideIcons.delete,
                      color: AppColors.textPrimary,
                      size: 24,
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border.withOpacity(0.6),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class StockAlertBadge extends StatelessWidget {
  final double stock;
  final double threshold;

  const StockAlertBadge({
    super.key,
    required this.stock,
    required this.threshold,
  });

  Color get _color {
    if (stock <= 0) return AppColors.danger;
    if (stock <= threshold) return AppColors.warning;
    return AppColors.success;
  }

  String get _label {
    if (stock <= 0) return 'Habis';
    if (stock <= threshold) return 'Stok menipis';
    return 'Stok ${stock.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}

class ProductGridCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final bool showFavorite;
  final VoidCallback? onFavoriteTap;

  const ProductGridCard({
    super.key,
    required this.product,
    required this.onTap,
    this.showFavorite = false,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    color: AppColors.primary.withOpacity(0.06),
                    alignment: Alignment.center,
                    child: const Icon(
                      LucideIcons.package,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                  if (showFavorite)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onFavoriteTap,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            product.isFavorite
                                ? LucideIcons.star
                                : LucideIcons.star,
                            size: 16,
                            color: product.isFavorite
                                ? AppColors.warning
                                : AppColors.border,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: StockAlertBadge(
                      stock: product.stock,
                      threshold: product.stockAlertThreshold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatRupiah(product.priceSell),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
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

class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class CartLineItem extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  const CartLineItem({
    super.key,
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final qtyLabel = item.qty == item.qty.roundToDouble()
        ? item.qty.toStringAsFixed(0)
        : item.qty.toStringAsFixed(2);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.unitName} x $qtyLabel',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatRupiah(item.subtotal),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepperButton(
                  icon: LucideIcons.minus,
                  onTap: onDecrease,
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    qtyLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _StepperButton(
                  icon: LucideIcons.plus,
                  onTap: onIncrease,
                  highlight: true,
                ),
                const SizedBox(width: 4),
                _StepperButton(
                  icon: LucideIcons.trash2,
                  onTap: onRemove,
                  danger: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;
  final bool danger;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    this.highlight = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.danger
        : highlight
            ? AppColors.primary
            : AppColors.textSecondary;
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(AppTheme.radiusInput),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

class FavoriteQuickButton extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const FavoriteQuickButton({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.package,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatRupiah(product.priceSell),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentMethodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const PaymentMethodSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  static const methods = ['tunai', 'qris', 'ewallet', 'split', 'utang'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final method in methods)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _MethodItem(
                method: method,
                selected: selected == method,
                onTap: () => onSelected(method),
              ),
            ),
          ),
      ],
    );
  }
}

class _MethodItem extends StatelessWidget {
  final String method;
  final bool selected;
  final VoidCallback onTap;

  const _MethodItem({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(paymentMethodIcon(method), size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              paymentMethodLabel(method),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectionProvider).valueOrNull;
    if (online == true) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.danger,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.wifiOff, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'Offline — transaksi disimpan di perangkat',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

Future<double?> showChangeCalculatorSheet(
  BuildContext context, {
  required double total,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ChangeCalculatorSheet(total: total),
  );
}

class _ChangeCalculatorSheet extends StatefulWidget {
  final double total;

  const _ChangeCalculatorSheet({required this.total});

  @override
  State<_ChangeCalculatorSheet> createState() => _ChangeCalculatorSheetState();
}

class _ChangeCalculatorSheetState extends State<_ChangeCalculatorSheet> {
  String _cash = '';

  double get _cashValue => double.tryParse(_cash) ?? 0;

  double get _change => _cashValue - widget.total;

  void _onKey(String key) {
    setState(() {
      if (key == 'backspace') {
        if (_cash.isNotEmpty) _cash = _cash.substring(0, _cash.length - 1);
      } else if (key == '.') {
        if (!_cash.contains('.')) {
          _cash = _cash.isEmpty ? '0.' : '$_cash.';
        }
      } else {
        if (_cash == '0') {
          _cash = key;
        } else if (_cash.length < 10) {
          _cash += key;
        }
      }
    });
  }

  void _setQuick(num value) {
    setState(() => _cash = value.toStringAsFixed(0));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Kembalian',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              _change < 0 ? 'Kurang' : formatRupiah(_change),
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: _change < 0 ? AppColors.danger : AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tunai: ${_cash.isEmpty ? '0' : _cash}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _QuickCashChip(
                  label: 'Uang Pas',
                  onTap: () => _setQuick(widget.total),
                ),
                _QuickCashChip(label: '10rb', onTap: () => _setQuick(10000)),
                _QuickCashChip(label: '20rb', onTap: () => _setQuick(20000)),
                _QuickCashChip(label: '50rb', onTap: () => _setQuick(50000)),
                _QuickCashChip(label: '100rb', onTap: () => _setQuick(100000)),
              ],
            ),
            const SizedBox(height: 12),
            NumericKeypad(onKey: _onKey),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _change < 0 ? null : () => Navigator.pop(context, _cashValue),
                child: const Text('Konfirmasi'),
              ),
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
