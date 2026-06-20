import 'package:flutter/material.dart';
import '../theme/habit_colors.dart';

class AchievementBadge extends StatelessWidget {
  final int streak;
  final double size;

  const AchievementBadge({super.key, required this.streak, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final badge = _badgeForStreak(streak);
    if (badge == null) return const SizedBox.shrink();

    return Tooltip(
      message: '${badge.label} — $streak day streak',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: badge.gradient,
          boxShadow: [
            BoxShadow(
              color: badge.glowColor.withValues(alpha: 0.4),
              blurRadius: 6,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Center(
          child: Text(badge.emoji, style: TextStyle(fontSize: size * 0.5)),
        ),
      ),
    );
  }

  _BadgeInfo? _badgeForStreak(int streak) {
    if (streak >= 100) {
      return _BadgeInfo('💎', '100+ day legend', HabitColors.accentColors[9].withValues(alpha: 0.3),
          const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)]));
    }
    if (streak >= 60) {
      return _BadgeInfo('🏆', '60+ day champion', HabitColors.accentColors[3].withValues(alpha: 0.3),
          const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)]));
    }
    if (streak >= 30) {
      return _BadgeInfo('🌟', '30+ day star', HabitColors.accentColors[1].withValues(alpha: 0.3),
          const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]));
    }
    if (streak >= 21) {
      return _BadgeInfo('🔥', '21-day streak', HabitColors.accentColors[0].withValues(alpha: 0.3),
          const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF3B82F6)]));
    }
    if (streak >= 14) {
      return _BadgeInfo('⚡', '14-day streak', HabitColors.accentColors[7].withValues(alpha: 0.3),
          const LinearGradient(colors: [Color(0xFF14B8A6), Color(0xFF10B981)]));
    }
    if (streak >= 7) {
      return _BadgeInfo('🌱', '7-day streak', HabitColors.accentColors[2].withValues(alpha: 0.3),
          const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06B6D4)]));
    }
    return null;
  }
}

class _BadgeInfo {
  final String emoji;
  final String label;
  final Color glowColor;
  final Gradient gradient;
  _BadgeInfo(this.emoji, this.label, this.glowColor, this.gradient);
}