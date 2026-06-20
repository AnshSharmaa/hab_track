import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF070B12);
  static const bgSecondary = Color(0xFF0B1220);
  static const sidebar = Color(0xFF0D1321);
  static const surface = Color(0xFF141D2E);
  static const surfaceAlt = Color(0xFF101929);
  static const surfaceGlass = Color(0xB31A2438);
  static const surfaceGlassSoft = Color(0x8C182133);
  static const border = Color(0xFF263247);
  static const borderGlass = Color(0x4DA7BBFF);
  static const overlay = Color(0x66101826);
  static const textPrimary = Colors.white;
  static const textMuted = Color(0xFFAAB8D1);
  static const textSubtle = Color(0xFF72829F);
  static const accent = Color(0xFF91A0FF);
  static const accentSoft = Color(0xFFC7D1FF);
  static const accentGlow = Color(0x665A78FF);
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
}

class AppSpacing {
  static const double pageHorizontal = 20;
  static const double pageTop = 24;
  static const double cardPadding = 16;
}

class AppEffects {
  // Main global bloom controls for glass tiles/cards.
  static const double tileBloomBlur = 10;
  static const double tileBloomSpread = -10;
  static const Offset tileBloomOffset = Offset(0, 10);

  static const double chipBloomBlur = 6;
  static const double chipBloomSpread = -5;
  static const Offset chipBloomOffset = Offset(0, 3);
}

class AppDecorations {
  static LinearGradient pageGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.bg, AppColors.bgSecondary],
    );
  }

  static BoxDecoration glassCard({bool elevated = false}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.borderGlass),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.surfaceGlass,
          elevated ? AppColors.surface : AppColors.surfaceGlassSoft,
        ],
      ),
      boxShadow: elevated
          ? [
              const BoxShadow(
                color: AppColors.accentGlow,
                blurRadius: AppEffects.tileBloomBlur,
                spreadRadius: AppEffects.tileBloomSpread,
                offset: AppEffects.tileBloomOffset,
              ),
            ]
          : const [],
    );
  }

  static BoxDecoration glassChip({required bool selected}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.65)
            : AppColors.borderGlass,
      ),
      color: selected
          ? AppColors.accent.withValues(alpha: 0.16)
          : AppColors.surfaceGlassSoft,
      boxShadow: selected
          ? [
              const BoxShadow(
                color: AppColors.accentGlow,
                blurRadius: AppEffects.chipBloomBlur,
                spreadRadius: AppEffects.chipBloomSpread,
                offset: AppEffects.chipBloomOffset,
              ),
            ]
          : const [],
    );
  }
}

bool isCompactWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 900;
bool isPhoneWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 680;
