import 'package:flutter/material.dart';
import '../theme/habit_colors.dart';

class RingProgress extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final int colorIndex;
  final Widget? child;
  final bool animate;

  const RingProgress({
    super.key,
    required this.progress,
    this.size = 32,
    this.strokeWidth = 3,
    this.colorIndex = 0,
    this.child,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate ? 0 : progress, end: progress),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: strokeWidth,
                backgroundColor: HabitColors.getColorWithAlpha(colorIndex, 0.15),
                valueColor: AlwaysStoppedAnimation(
                  HabitColors.getColor(colorIndex),
                ),
                strokeCap: StrokeCap.round,
              ),
            ),
            if (this.child != null)
              SizedBox(
                width: size * 0.6,
                height: size * 0.6,
                child: FittedBox(child: this.child),
              ),
          ],
        ),
      ),
    );
  }
}