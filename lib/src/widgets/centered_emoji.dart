import 'package:flutter/material.dart';

/// Emoji icon sized like Flutter's [Icon], with a small upward nudge so
/// color-emoji ink sits on the true visual center.
class CenteredEmoji extends StatelessWidget {
  const CenteredEmoji(
    this.emoji, {
    super.key,
    this.size = 16,
  });

  /// Upward shift as a fraction of [size] (negative Y).
  static const double _opticalNudgeFactor = 0.12;

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, -size * _opticalNudgeFactor),
          child: Text(
            emoji,
            textAlign: TextAlign.center,
            overflow: TextOverflow.visible,
            style: TextStyle(
              inherit: false,
              fontSize: size,
              height: 1.0,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
        ),
      ),
    );
  }
}
