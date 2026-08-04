import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// HabTrack design tokens — Railway · Cosmic Midnight Express.
///
/// A calm, powerful journey through a dark, starlit environment.
/// Deep near-black space (#13111c) with a single focused accent of
/// cosmic lilac (#553f83) for primary actions.
///
/// App-facing colors feed:
/// - [AppTheme.colorScheme] / [AppTheme.shadDark] (shadcn)
/// - [AppTheme.materialBuilder] (Material via ShadApp)
/// - Direct screen usage (`AppColors.bg`, etc.)
class AppColors {
  // Surfaces (Railway · Cosmic Midnight Express)
  static const bg = Color(0xFF13111C); // Deep Space — page background
  static const bgSecondary = Color(0xFF0D0C14); // Black Hole — darkest UI
  static const sidebar = Color(0xFF0D0C14); // Black Hole
  static const surface = Color(0xFF1A191F); // Surface — cards, secondary surfaces
  static const surfaceAlt = Color(0xFF0D0C14); // Black Hole
  static const surfaceGlass = Color(0xCC1A191F);
  static const surfaceGlassSoft = Color(0x991A191F);

  // Aliases kept for theme API stability
  static const abyss = bgSecondary;
  static const deepLagoon = surfaceAlt;
  static const midnightTide = bgSecondary;

  // Borders
  static const border = Color(0xFF33323E); // Crater
  static const borderHairline = Color(0xFF33323E);
  static const borderGlass = Color(0xFF33323E);

  static const overlay = Color(0x6613111C);

  // Text (Railway)
  static const textPrimary = Color(0xFFF7F7F8); // Starlight
  static const textMuted = Color(0xFFD0CFD2); // Starlight Dim
  static const textSubtle = Color(0xFFA1A0AB); // Comet

  // Accent (Railway · Cosmic Lilac + Supernova)
  static const accent = Color(0xFF553F83); // Cosmic Lilac
  static const accentSoft = Color(0xFFBF92EC); // Nebula Haze
  static const accentGlow = Color(0x33A05FCF); // Supernova 20%
  static const tealPulse = Color(0xFFA05FCF); // Supernova

  // Railway named tokens
  static const supernova = Color(0xFFA05FCF);
  static const nebulaHaze = Color(0xFFBF92EC);
  static const asteroid = Color(0xFF868593);
  static const comet = Color(0xFFA1A0AB);
  static const starlightDim = Color(0xFFD0CFD2);
  static const crater = Color(0xFF33323E);
  static const deepSpace = Color(0xFF13111C);

  // Semantic
  static const success = Color(0xFF42946E);
  static const danger = Color(0xFFD82C20);
  static const warning = Color(0xFFA1A0AB); // Comet-based warning
  static const highPriority = Color(0xFFBF92EC);

  // Picker theming (date / time pickers)
  static const pickerPrimary = accent;
  static const pickerSurface = surfaceAlt;

  // Button state colors (alpha variants of cosmic lilac / supernova)
  static const accentHover = Color(0x1A553F83);
  static const accentPressed = Color(0x33553F83);

  static const confettiColors = <Color>[
    Color(0xFFBF92EC), // nebula haze
    Color(0xFFA05FCF), // supernova
    Color(0xFF553F83), // cosmic lilac
    Color(0xFFF7F7F8), // starlight
    Color(0xFFD0CFD2), // starlight dim
    Color(0xFF42946E), // success
    Color(0xFFA05FCF), // supernova
    Color(0xFFBF92EC), // nebula haze
    Color(0xFFF7F7F8), // starlight
    Color(0xFF553F83), // cosmic lilac
    Colors.white,
  ];
}

class AppSpacing {
  static const double pageHorizontal = 20;
  static const double pageTop = 24;
  static const double cardPadding = 32; // Railway card padding
  static const double elementGap = 24;
}

class AppRadii {
  static const double card = 12; // cards
  static const double button = 8; // buttons
  static const double tag = 9999; // tags — full pill
  static const double largePill = 9999;
  static const double input = 6; // inputs
}

class AppEffects {
  // Railway elevation is expressed through surface shifts and borders,
  // not shadows. The only "shadow" is an inset white highlight.
  static const double tileBloomBlur = 0;
  static const double tileBloomSpread = 0;
  static const Offset tileBloomOffset = Offset.zero;

  static const double chipBloomBlur = 0;
  static const double chipBloomSpread = 0;
  static const Offset chipBloomOffset = Offset.zero;

  static const double glowBlur = 0;
  static const double glowSpread = 0;
  static const Offset glowOffset = Offset.zero;

  static const Color mintGlowShadow = Color(0x1AFFFFFF); // subtle inset highlight
}

class AppTextStyles {
  /// Inter — eyebrow labels (uppercase tracking)
  static TextStyle get eyebrow => GoogleFonts.inter(
        color: AppColors.textSubtle,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      );

  /// IBM Plex Serif — section titles
  static TextStyle get title => GoogleFonts.ibmPlexSerif(
        color: AppColors.textPrimary,
        fontSize: 26,
        fontWeight: FontWeight.w500,
        height: 1.20,
        letterSpacing: -0.52,
      );

  /// IBM Plex Serif — large section headings
  static TextStyle get heading => GoogleFonts.ibmPlexSerif(
        color: AppColors.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w500,
        height: 1.20,
        letterSpacing: -0.48,
      );

  /// Inter — body copy
  static TextStyle get body => GoogleFonts.inter(
        color: AppColors.textMuted,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        letterSpacing: -0.1,
      );

  /// Inter — small body
  static TextStyle get bodySm => GoogleFonts.inter(
        color: AppColors.textMuted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: -0.14,
      );

  /// Inter — caption
  static TextStyle get caption => GoogleFonts.inter(
        color: AppColors.textSubtle,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: -0.12,
      );

  /// Inter — chips / tags
  static TextStyle get chip => GoogleFonts.inter(
        color: AppColors.accentSoft,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      );

  /// Inter — buttons
  static TextStyle get button => GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );

  /// Inter — form labels
  static TextStyle get label => GoogleFonts.inter(
        color: AppColors.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      );
}

class AppDecorations {
  static LinearGradient pageGradient() {
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.bg, Color(0xFF0F0D16)],
    );
  }

  static LinearGradient atmosphereGradient() => pageGradient();

  static BoxDecoration glassCard({bool elevated = false}) {
    // Railway elevation = surface shift + 1px Crater border, no shadows.
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadii.card),
      border: Border.all(color: AppColors.borderGlass),
      color: elevated ? AppColors.surface : AppColors.surfaceGlass,
    );
  }

  /// Alias for elevated surfaces — keep API for featured cards.
  static BoxDecoration glowCard() => glassCard(elevated: true);

  static BoxDecoration glassChip({required bool selected}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadii.tag),
      border: Border.all(
        color: selected ? AppColors.supernova : AppColors.borderGlass,
      ),
      color: selected
          ? AppColors.accent.withValues(alpha: 0.20)
          : AppColors.surfaceGlassSoft,
    );
  }

  static BoxDecoration ghostPill() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadii.tag),
      color: Colors.transparent,
      border: Border.all(color: AppColors.supernova),
    );
  }

  static BoxDecoration pillButton({bool primary = true, bool enabled = true}) {
    final active = primary && enabled;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadii.button),
      color: active
          ? AppColors.accent
          : (primary ? AppColors.surfaceAlt : Colors.transparent),
      border: primary
          ? Border.all(color: const Color(0x26FFFFFF)) // rgba(255,255,255,0.15)
          : Border.all(color: AppColors.borderGlass),
    );
  }

  static InputDecoration field({String? hintText}) {
    final radius = BorderRadius.circular(AppRadii.input);
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(color: AppColors.textSubtle, fontSize: 15),
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
        borderSide: const BorderSide(color: AppColors.supernova, width: 1.5),
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
    ring: AppColors.tealPulse,
    selection: AppColors.accentGlow,
    custom: {
      'mintGlow': AppColors.tealPulse,
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
        ),
        outlineButtonTheme: const ShadButtonTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          hoverBackgroundColor: Colors.transparent,
          pressedBackgroundColor: Colors.transparent,
        ),
        destructiveButtonTheme: const ShadButtonTheme(
          backgroundColor: AppColors.danger,
          foregroundColor: AppColors.textPrimary,
        ),
        cardTheme: const ShadCardTheme(
          backgroundColor: AppColors.surface,
          padding: EdgeInsets.all(AppSpacing.cardPadding),
        ),
        inputTheme: ShadInputTheme(
          placeholderStyle: GoogleFonts.inter(
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
      primary: AppColors.accent,
      onPrimary: AppColors.textPrimary,
      secondary: AppColors.tealPulse,
      onSecondary: AppColors.textPrimary,
      outline: AppColors.border,
      surfaceContainerHighest: AppColors.surfaceAlt,
    );

    final inter = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textMuted,
      displayColor: AppColors.textPrimary,
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
        selectedColor: AppColors.accent.withValues(alpha: 0.20),
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
        hintStyle: GoogleFonts.inter(
          color: AppColors.textSubtle,
          fontSize: 15,
        ),
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
          borderSide: const BorderSide(color: AppColors.tealPulse, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textPrimary,
          textStyle: AppTextStyles.button,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          side: const BorderSide(color: Color(0x26FFFFFF)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderGlass),
          textStyle: AppTextStyles.button,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.supernova),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.accent.withValues(alpha: 0.35),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            color: selected ? AppColors.textPrimary : AppColors.textSubtle,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.supernova : AppColors.textSubtle,
          );
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.textPrimary
              : AppColors.asteroid;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.accent.withValues(alpha: 0.7)
              : AppColors.surfaceAlt;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.supernova,
        linearTrackColor: AppColors.surfaceAlt,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: GoogleFonts.inter(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.borderGlass),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      timePickerTheme: _timePickerTheme(),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surfaceAlt,
        headerBackgroundColor: AppColors.surface,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          return AppColors.textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return Colors.transparent;
        }),
        todayForegroundColor: const WidgetStatePropertyAll(AppColors.supernova),
        todayBorder: const BorderSide(color: AppColors.supernova),
      ),
      textTheme: inter.copyWith(
        displayLarge: GoogleFonts.ibmPlexSerif(
          color: AppColors.textPrimary,
          fontSize: 40,
          fontWeight: FontWeight.w500,
          height: 1.2,
          letterSpacing: -0.6,
        ),
        headlineMedium: GoogleFonts.ibmPlexSerif(
          color: AppColors.textPrimary,
          fontSize: 36,
          fontWeight: FontWeight.w500,
          height: 1.2,
          letterSpacing: -0.72,
        ),
        titleLarge: GoogleFonts.ibmPlexSerif(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w500,
          height: 1.33,
        ),
        bodyLarge: GoogleFonts.inter(
          color: AppColors.textMuted,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.6,
          letterSpacing: -0.1,
        ),
        bodyMedium: GoogleFonts.inter(
          color: AppColors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
          letterSpacing: -0.14,
        ),
        bodySmall: GoogleFonts.inter(
          color: AppColors.textSubtle,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.5,
          letterSpacing: -0.12,
        ),
        labelLarge: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: GoogleFonts.inter(
          color: AppColors.textSubtle,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.supernova),
    );
  }

  static TimePickerThemeData _timePickerTheme() {
    return TimePickerThemeData(
      backgroundColor: AppColors.surfaceAlt,
      dialBackgroundColor: AppColors.surface,
      dialHandColor: AppColors.supernova,
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
      entryModeIconColor: AppColors.supernova,
      helpTextStyle: GoogleFonts.inter(color: AppColors.textMuted),
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
  Color get success => custom['success'] ?? AppColors.success;
  Color get warning => custom['warning'] ?? AppColors.warning;
  Color get sidebar => custom['sidebar'] ?? background;
  Color get abyss => custom['abyss'] ?? background;
  Color get hairline => custom['hairline'] ?? border;
  Color get textSubtle => custom['textSubtle'] ?? mutedForeground;
}

bool isCompactWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 900;
bool isPhoneWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 680;