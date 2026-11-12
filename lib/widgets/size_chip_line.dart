import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Una sola fila de talles. Si no entran, el último chip es "+".
class SizeChipLine extends StatelessWidget {
  const SizeChipLine({super.key, required this.sizes});

  final List<String> sizes;

  static const gap = 6.0;

  @override
  Widget build(BuildContext context) {
    if (sizes.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
        .copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1.2,
          color: isDark ? const Color(0xFFF3F4F6) : AppColors.charcoal,
        );
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final labels = labelsThatFit(
          sizes,
          maxWidth: constraints.maxWidth,
          style: style,
          textScaler: scaler,
        );
        return Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              _SizeChip(label: labels[i], style: style, isDark: isDark),
            ],
          ],
        );
      },
    );
  }
}

/// Talles que entran en [maxWidth], cerrando con "+" cuando hay recorte.
List<String> labelsThatFit(
  List<String> sizes, {
  required double maxWidth,
  required TextStyle style,
  required TextScaler textScaler,
}) {
  if (sizes.isEmpty || maxWidth <= 0) return const [];
  final widths = [
    for (final size in sizes) chipWidth(size, style, textScaler),
  ];
  final plusWidth = chipWidth('+', style, textScaler);
  if (_rowWidth(widths, widths.length) <= maxWidth) return sizes;

  var count = 0;
  for (var i = 1; i <= widths.length; i++) {
    final total = _rowWidth(widths, i) + SizeChipLine.gap + plusWidth;
    if (total <= maxWidth) {
      count = i;
    } else {
      break;
    }
  }
  if (count == 0) {
    return plusWidth <= maxWidth ? const ['+'] : [sizes.first];
  }
  return [...sizes.take(count), '+'];
}

double chipWidth(String label, TextStyle style, TextScaler textScaler) {
  final painter = TextPainter(
    text: TextSpan(text: label, style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  return painter.width + 16 + 2;
}

double _rowWidth(List<double> widths, int count) {
  if (count <= 0) return 0;
  var total = 0.0;
  for (var i = 0; i < count; i++) {
    if (i > 0) total += SizeChipLine.gap;
    total += widths[i];
  }
  return total;
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.style,
    required this.isDark,
  });

  final String label;
  final TextStyle style;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevated : AppColors.lightMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Text(label, maxLines: 1, style: style),
    );
  }
}
