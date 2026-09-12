import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hab_track/src/widgets/centered_emoji.dart';

void main() {
  group('CenteredEmoji.nudgeFor', () {
    test('Android gets a downward correction (positive Y)', () {
      expect(CenteredEmoji.nudgeFor(TargetPlatform.android), greaterThan(0));
    });

    test('macOS keeps the historical upward value (regression guard)', () {
      expect(CenteredEmoji.nudgeFor(TargetPlatform.macOS), -0.12);
    });

    test('iOS matches macOS', () {
      expect(
        CenteredEmoji.nudgeFor(TargetPlatform.iOS),
        CenteredEmoji.nudgeFor(TargetPlatform.macOS),
      );
    });
  });
}
