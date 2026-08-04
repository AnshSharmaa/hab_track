import 'package:flutter/material.dart';

class HabitColors {
  /// Railway cosmic palette — purple-toned accents that stay within the
  /// starlit night theme. These are the only accents used for habits/todos.
  static const List<Color> accentColors = [
    Color(0xFFA05FCF), // supernova
    Color(0xFFBF92EC), // nebula haze
    Color(0xFF553F83), // cosmic lilac
    Color(0xFF8E6BC4), // muted violet
    Color(0xFF7A5AA8), // twilight orchid
    Color(0xFF9B7EDE), // soft lavender
    Color(0xFF6B4E9E), // deep purple
    Color(0xFFC4A7F0), // pale lilac
    Color(0xFF5A4599), // indigo night
    Color(0xFFA88BD6), // dusty violet
  ];

  static List<String> defaultEmojis = [
    '🔥', '💪', '📚', '🏃', '🧘', '🎯', '💧', '🥗',
    '✍️', '🎨', '🎵', '🌱', '🧠', '💤', '☀️', '🏋️',
  ];

  static List<String> todoEmojis = [
    '☑️', '📌', '📞', '🛒', '✉️', '💼', '🏠', '💡',
    '🧾', '🗓️', '🛠️', '🎁', '🧹', '📦', '✈️', '💰',
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