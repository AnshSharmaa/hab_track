import 'package:flutter/material.dart';

/// Centers emoji glyphs that otherwise look optically low due to font metrics.
class CenteredEmoji extends StatelessWidget {
  const CenteredEmoji(
    this.emoji, {
    super.key,
    this.size = 16,
  });

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          emoji,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size,
            height: 1,
            leadingDistribution: TextLeadingDistribution.even,
          ),
          strutStyle: StrutStyle(
            fontSize: size,
            height: 1,
            forceStrutHeight: true,
          ),
        ),
      ),
    );
  }
}
