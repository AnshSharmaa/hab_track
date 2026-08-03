import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// HabTrack design tokens.
///
/// App-facing colors feed:
/// - [AppTheme.colorScheme] / [AppTheme.shadDark] (shadcn)
/// - [AppTheme.materialBuilder] (Material via ShadApp)
/// - Direct screen usage (`AppColors.bg`, etc.)
///
/// Swap token values here to retheme without touching screen wiring.
class AppColors {
  // Surfaces (original HabTrack)
  static const bg = Color(0xFF070B12);
  static const bgSecondary = Color(0xFF0B1220);
  static const sidebar = Color(0xFF0D1321);
  static const surface = Color(0xFF141D2E);
  static const surfaceAlt = Color(0xFF101929);
  static const surfaceGlass = Color(0xB31A2438);
  static const surfaceGlassSoft = Color(0x8C182133);

  // Aliases kept for theme API stability (map onto original palette)
  static const abyss = bgSecondary;
  static const deepLagoon = surfaceAlt;
  static const midnightTide = bgSecondary;

  // Borders
  static const border = Color(0xFF263247);
  static const borderHairline = border;
  static const borderGlass = Color(0x4DA7BBFF);

  static const overlay = Color(0x66101826);

  // Text
  static const textPrimary = Colors.white;
  static const textMuted = Color(0xFFAAB8D1);
  static const textSubtle = Color(0xFF72829F);

  // Accent
  static const accent = Color(0xFF91A0FF);
  static const accentSoft = Color(0xFFC7D1FF);
  static const accentGlow = Color(0x665A78FF);
  static const tealPulse = Color(0xFF5A78FF);

  // Semantic
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
}

class AppSpacing {
  static const double pageHorizontal = 20;
  static const double pageTop = 24;
  static const double cardPadding = 16;
  static const double elementGap = 24;
}

class AppRadii {
  static const double card = 16;
  static const double button = 12;
  static const double tag = 999;
  static const double largePill = 37;
  static const double input = 12;
}

class AppEffects {
  static const double tileBloomBlur = 10;
  static const double tileBloomSpread = -10;
  static const Offset tileBloomOffset = Offset(0, 10);

  static const double chipBloomBlur = 6;
  static const double chipBloomSpread = -5;
  static const Offset chipBloomOffset = Offset(0, 3);

  static const double glowBlur = tileBloomBlur;
  static const double glowSpread = tileBloomSpread;
  static const Offset glowOffset = tileBloomOffset;

  static const Color mintGlowShadow = AppColors.accentGlow;
}

class AppTextStyles {
  static const eyebrow = TextStyle(
    color: AppColors.textSubtle,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  static const title = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const heading = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const body = TextStyle(
    color: AppColors.textMuted,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const bodySm = TextStyle(
    color: AppColors.textMuted,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const caption = TextStyle(
    color: AppColors.textSubtle,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const chip = TextStyle(
    color: AppColors.accentSoft,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const button = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static const label = TextStyle(
    color: AppColors.textMuted,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );
}

class AppDecorations {
  static LinearGradient pageGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.bg, AppColors.bgSecondary],
    );
  }

  static LinearGradient atmosphereGradient() => pageGradient();

  static BoxDecoration glassCard({bool elevated = false}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadii.card),
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
          ? const [
              BoxShadow(
                color: AppColors.accentGlow,
                blurRadius: AppEffects.tileBloomBlur,
                spreadRadius: AppEffects.tileBloomSpread,
                offset: AppEffects.tileBloomOffset,
              ),
            ]
          : const [],
    );
  }

  /// Alias for elevated glass — keep API for featured surfaces.
  static BoxDecoration glowCard() => glassCard(elevated: true);

  static BoxDecoration glassChip({required bool selected}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadii.tag),
      border: Border.all(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.65)
            : AppColors.borderGlass,
      ),
      color: selected
          ? AppColors.accent.withValues(alpha: 0.16)
          : AppColors.surfaceGlassSoft,
      boxShadow: selected
          ? const [
              BoxShadow(
                color: AppColors.accentGlow,
                blurRadius: AppEffects.chipBloomBlur,
                spreadRadius: AppEffects.chipBloomSpread,
                offset: AppEffects.chipBloomOffset,
              ),
            ]
          : const [],
    );
  }

  static BoxDecoration ghostPill() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadii.tag),
      color: Colors.transparent,
      border: Border.all(color: AppColors.accent.withValues(alpha: 0.55)),
    );
  }

  static BoxDecoration pillButton({bool primary = true, bool enabled = true}) {
    final active = primary && enabled;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadii.button),
      color: active
          ? AppColors.accent.withValues(alpha: 0.95)
          : (primary ? AppColors.surfaceAlt : Colors.transparent),
      border: primary
          ? null
          : Border.all(color: AppColors.accent.withValues(alpha: 0.55)),
      boxShadow: active
          ? const [
              BoxShadow(
                color: AppColors.accentGlow,
                blurRadius: 16,
                spreadRadius: -4,
                offset: Offset(0, 10),
              ),
            ]
          : const [],
    );
  }

  static InputDecoration field({String? hintText}) {
    final radius = BorderRadius.circular(AppRadii.input);
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.textSubtle, fontSize: 15),
      filled: true,
      fillColor: AppColors.surfaceGlassSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    );
  }
}

/// Root theme wiring — Shadcn + Material. Token values live in [AppColors].
class AppTheme {
  AppTheme._();

  /// Mapped onto shadcn semantic roles from [AppColors].
  static const ShadColorScheme colorScheme = ShadColorScheme(
    background: AppColors.bg,
    foreground: AppColors.textPrimary,
    card: AppColors.surface,
    cardForeground: AppColors.textPrimary,
    popover: AppColors.surfaceAlt,
    popoverForeground: AppColors.textPrimary,
    primary: AppColors.accent,
    primaryForeground: AppColors.textPrimary,
    secondary: AppColors.surfaceAlt,
    secondaryForeground: AppColors.textPrimary,
    muted: AppColors.surfaceAlt,
    mutedForeground: AppColors.textMuted,
    accent: AppColors.surface,
    accentForeground: AppColors.textPrimary,
    destructive: AppColors.danger,
    destructiveForeground: AppColors.textPrimary,
    border: AppColors.border,
    input: AppColors.border,
    ring: AppColors.accent,
    selection: AppColors.accentGlow,
    custom: {
      'mintGlow': AppColors.accent,
      'mintSoft': AppColors.accentSoft,
      'tealPulse': AppColors.tealPulse,
      'success': AppColors.success,
      'warning': AppColors.warning,
      'sidebar': AppColors.sidebar,
      'abyss': AppColors.abyss,
      'hairline': AppColors.borderHairline,
      'textSubtle': AppColors.textSubtle,
    },
  );

  static ShadThemeData get shadDark => ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        radius: BorderRadius.circular(AppRadii.card),
        primaryButtonTheme: const ShadButtonTheme(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textPrimary,
          hoverBackgroundColor: AppColors.accentSoft,
          pressedBackgroundColor: AppColors.tealPulse,
        ),
        outlineButtonTheme: const ShadButtonTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.accent,
          hoverBackgroundColor: Color(0x1491A0FF),
          pressedBackgroundColor: Color(0x2891A0FF),
        ),
        destructiveButtonTheme: const ShadButtonTheme(
          backgroundColor: AppColors.danger,
          foregroundColor: AppColors.textPrimary,
        ),
        cardTheme: const ShadCardTheme(
          backgroundColor: AppColors.surface,
          padding: EdgeInsets.all(AppSpacing.cardPadding),
        ),
        inputTheme: const ShadInputTheme(
          placeholderStyle: TextStyle(
            color: AppColors.textSubtle,
            fontSize: 15,
          ),
        ),
      );

  /// Extends Material [ThemeData] derived by [ShadApp] from [shadDark].
  static ThemeData materialBuilder(BuildContext context, ThemeData base) {
    final scheme = base.colorScheme.copyWith(
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      secondary: AppColors.tealPulse,
      onSecondary: AppColors.textPrimary,
      outline: AppColors.border,
      surfaceContainerHighest: AppColors.surfaceAlt,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      dividerColor: AppColors.border,
      splashColor: AppColors.accent.withValues(alpha: 0.12),
      highlightColor: AppColors.accent.withValues(alpha: 0.08),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.borderGlass),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceGlassSoft,
        selectedColor: AppColors.accent.withValues(alpha: 0.16),
        side: const BorderSide(color: AppColors.borderGlass),
        labelStyle: AppTextStyles.chip,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.tag),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceGlassSoft,
        hintStyle: const TextStyle(color: AppColors.textSubtle, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textPrimary,
          textStyle: AppTextStyles.button,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent),
          textStyle: AppTextStyles.button.copyWith(color: AppColors.accent),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.accent.withValues(alpha: 0.26),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppColors.accentSoft : AppColors.textSubtle,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.accentSoft : AppColors.textSubtle,
          );
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.accentSoft
              : AppColors.textSubtle;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.surfaceAlt;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.surfaceAlt,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      timePickerTheme: _timePickerTheme(),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surfaceAlt,
        headerBackgroundColor: AppColors.surface,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.textPrimary;
          }
          return AppColors.textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return Colors.transparent;
        }),
        todayForegroundColor: const WidgetStatePropertyAll(AppColors.accent),
        todayBorder: const BorderSide(color: AppColors.accent),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: AppTextStyles.heading,
        titleLarge: AppTextStyles.title,
        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.bodySm,
        bodySmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.button,
        labelSmall: AppTextStyles.eyebrow,
      ),
      iconTheme: const IconThemeData(color: AppColors.accentSoft),
    );
  }

  static TimePickerThemeData _timePickerTheme() {
    return TimePickerThemeData(
      backgroundColor: AppColors.surfaceAlt,
      dialBackgroundColor: AppColors.bg,
      dialHandColor: AppColors.accent,
      hourMinuteTextColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.textPrimary
            : AppColors.textMuted,
      ),
      hourMinuteColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.accent
            : AppColors.surface,
      ),
      dayPeriodTextColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.textPrimary
            : AppColors.textMuted,
      ),
      dayPeriodColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.accent
            : AppColors.surface,
      ),
      entryModeIconColor: AppColors.accentSoft,
      helpTextStyle: const TextStyle(color: AppColors.textMuted),
    );
  }

  static Widget pickerOverlay(BuildContext context, Widget? child) {
    return child ?? const SizedBox.shrink();
  }
}

/// Typed accessors for [ShadColorScheme.custom] extras.
extension HabTrackShadColors on ShadColorScheme {
  Color get mintGlow => custom['mintGlow'] ?? primary;
  Color get mintSoft => custom['mintSoft'] ?? primary;
  Color get tealPulse => custom['tealPulse'] ?? secondary;
  Color get success => custom['success'] ?? const Color(0xFF22C55E);
  Color get warning => custom['warning'] ?? const Color(0xFFF59E0B);
  Color get sidebar => custom['sidebar'] ?? background;
  Color get abyss => custom['abyss'] ?? background;
  Color get hairline => custom['hairline'] ?? border;
  Color get textSubtle => custom['textSubtle'] ?? mutedForeground;
}

bool isCompactWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 900;
bool isPhoneWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 680;
