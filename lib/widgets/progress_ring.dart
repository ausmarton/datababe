import 'dart:math' as math;

import 'package:flutter/material.dart';

class ProgressRing extends StatelessWidget {
  final double fraction;
  final IconData icon;
  final Color color;
  final String actual;
  final String target;
  final String label;
  final bool isInferred;
  final VoidCallback? onTap;

  const ProgressRing({
    super.key,
    required this.fraction,
    required this.icon,
    required this.color,
    required this.actual,
    required this.target,
    required this.label,
    this.isInferred = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = fraction >= 0.8
        ? Colors.green
        : fraction >= 0.4
            ? Colors.amber
            : Colors.red;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(56, 56),
                    painter: _RingPainter(
                      fraction: fraction.clamp(0.0, 1.0),
                      color: statusColor,
                      backgroundColor: statusColor.withValues(alpha: 0.15),
                    ),
                  ),
                  Icon(icon, size: 20, color: color),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$actual / $target',
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              isInferred ? '$label (avg)' : label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color backgroundColor;

  _RingPainter({
    required this.fraction,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    const strokeWidth = 5.0;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      fraction != oldDelegate.fraction || color != oldDelegate.color;
}
