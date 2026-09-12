import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Emoji icon sized like Flutter's [Icon], with a small optical correction
/// so color-emoji ink sits on the true visual center.
///
/// The correction is platform-aware: Android ships Noto Color Emoji (plus
/// OEM variants on Samsung/Xiaomi), whose glyph cells reserve extra space
/// *below* the ink, so the visible glyph sits above the text-box center.
/// Apple platforms use near-symmetric cells, so the historical macOS-tuned
/// value is kept there untouched.
class CenteredEmoji extends StatelessWidget {
  const CenteredEmoji(this.emoji, {super.key, this.size = 16});

  /// Upward shift as a fraction of [size] (negative Y) for Apple platforms.
  /// Historically tuned on macOS — must not change without re-verifying there.
  static const double _appleNudgeFactor = -0.12;

  /// Downward shift as a fraction of [size] (positive Y) for Android,
  /// compensating the high-sitting ink of Noto/OEM color-emoji glyphs.
  static const double _androidNudgeFactor = 0.10;

  final String emoji;
  final double size;

  @visibleForTesting
  static double nudgeFor(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return _androidNudgeFactor;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return _appleNudgeFactor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, size * nudgeFor(defaultTargetPlatform)),
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
