import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme.dart';

enum EmptyStateType { product, transaction, category, debt, search, generic }

class EmptyState extends StatelessWidget {
  final EmptyStateType type;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.type = EmptyStateType.generic,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  String get _defaultMessage {
    switch (type) {
      case EmptyStateType.product:
        return 'Belum ada produk';
      case EmptyStateType.transaction:
        return 'Belum ada transaksi';
      case EmptyStateType.category:
        return 'Belum ada kategori';
      case EmptyStateType.debt:
        return 'Belum ada utang';
      case EmptyStateType.search:
        return 'Pencarian tidak ditemukan';
      case EmptyStateType.generic:
        return 'Kosong';
    }
  }

  IconData get _icon {
    switch (type) {
      case EmptyStateType.product:
        return LucideIcons.packageOpen;
      case EmptyStateType.transaction:
        return LucideIcons.receipt;
      case EmptyStateType.category:
        return LucideIcons.tags;
      case EmptyStateType.debt:
        return LucideIcons.wallet;
      case EmptyStateType.search:
        return LucideIcons.searchX;
      case EmptyStateType.generic:
        return LucideIcons.inbox;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icon,
                size: 36,
                color: AppColors.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? _defaultMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(LucideIcons.plus, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
