import 'package:flutter/material.dart';

class HabitColors {
  static const List<Color> accentColors = [
    Color(0xFF6366F1), // indigo
    Color(0xFFEC4899), // pink
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFF3B82F6), // blue
    Color(0xFF8B5CF6), // violet
    Color(0xFFEF4444), // red
    Color(0xFF14B8A6), // teal
    Color(0xFFF97316), // orange
    Color(0xFF06B6D4), // cyan
  ];

  static List<String> defaultEmojis = [
    '🔥', '💪', '📚', '🏃', '🧘', '🎯', '💧', '🥗',
    '✍️', '🎨', '🎵', '🌱', '🧠', '💤', '☀️', '🏋️',
  ];

  static Color getColor(int index) => accentColors[index % accentColors.length];

  static Color getColorWithAlpha(int index, double alpha) =>
      getColor(index).withValues(alpha: alpha);

  static String getEmoji(int index) =>
      defaultEmojis[index % defaultEmojis.length];

  static LinearGradient habitGradient(int index) {
    final base = getColor(index);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [base.withValues(alpha: 0.25), base.withValues(alpha: 0.08)],
    );
  }
}