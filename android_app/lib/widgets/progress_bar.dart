import 'package:flutter/material.dart';

import '../theme.dart';

class StockProgressBar extends StatelessWidget {
  final double current;
  final double max;
  final double height;
  final bool showLabel;

  const StockProgressBar({
    super.key,
    required this.current,
    required this.max,
    this.height = 8,
    this.showLabel = true,
  });

  double get _fraction => max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;

  Color get _color {
    if (_fraction <= 0.15) return AppColors.danger;
    if (_fraction <= 0.35) return AppColors.warning;
    return AppColors.success;
  }

  String get _label {
    if (max == 0) return '0';
    return '${current.toStringAsFixed(0)} / ${max.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              _label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _color,
              ),
            ),
          ),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: FractionallySizedBox(
            widthFactor: _fraction,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
