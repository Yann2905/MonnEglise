/*
 * FICHIER : lib/core/app_theme.dart
 *
 * REDESIGN "SANCTUAIRE" — Naval profond + Or chaud
 * Light : Parchemin (#F7F4EF) + Or brun (#B8820F)
 * Dark  : Navy (#0F1B2D) + Or lumineux (#C9A84C)
 *
 * Typographie : Google Fonts — Cormorant Garamond (titres) + DM Sans (corps)
 * Ajouter dans pubspec.yaml :
 *   google_fonts: ^6.0.0
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // ══════════════════════════════════════════════
  //  PALETTE SANCTUAIRE
  // ══════════════════════════════════════════════

  // — Or (s'adapte selon le mode) —
  static const Color goldLight  = Color(0xFFB8820F); // Or brun (lisible sur parchemin)
  static const Color goldDark   = Color(0xFFC9A84C); // Or lumineux (sur navy)
  static const Color goldFill   = Color(0xFFFDF3E0); // Fond doré clair
  static const Color goldBorder = Color(0xFFE8C97A); // Bordure or

  // — Light Mode —
  static const Color parchment      = Color(0xFFF7F4EF); // Fond principal
  static const Color parchmentCard  = Color(0xFFFFFFFF); // Fond cartes
  static const Color parchmentDeep  = Color(0xFFEEE9E0); // Fond inputs
  static const Color inkPrimary     = Color(0xFF1A1208); // Texte principal
  static const Color inkSecondary   = Color(0xFF5C4E2E); // Texte secondaire
  static const Color inkTertiary    = Color(0xFF9A8B70); // Texte tertiaire

  // — Dark Mode —
  static const Color navy           = Color(0xFF0F1B2D); // Fond principal
  static const Color navy2          = Color(0xFF162236); // Fond header
  static const Color navy3          = Color(0xFF1E3050); // Fond cartes
  static const Color snowPrimary    = Color(0xFFF5F0E8); // Texte principal
  static const Color snowSecondary  = Color(0xFFA8B4C2); // Texte secondaire
  static const Color snowTertiary   = Color(0xFF6A7A8C); // Texte tertiaire

  // — Sémantiques (partagées) —
  static const Color colorBlue      = Color(0xFF1565C0);
  static const Color colorBlueBg    = Color(0xFFEBF3FB);
  static const Color colorBlueDark  = Color(0xFF64B5F6);
  static const Color colorGreen     = Color(0xFF2E7D32);
  static const Color colorGreenBg   = Color(0xFFEBF5EB);
  static const Color colorGreenDark = Color(0xFF66BB6A);
  static const Color colorOrange    = Color(0xFFBF5E00);
  static const Color colorOrangeBg  = Color(0xFFFDF0E0);
  static const Color colorOrangeDark= Color(0xFFFFA726);
  static const Color colorRed       = Color(0xFFB71C1C);
  static const Color colorRedBg     = Color(0xFFFDECEA);
  static const Color colorRedDark   = Color(0xFFEF5350);

  // ══════════════════════════════════════════════
  //  THÈME CLAIR — PARCHEMIN
  // ══════════════════════════════════════════════
  static ThemeData get lightTheme {
    const Color primary = goldLight;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: parchment,
      primaryColor: primary,

      colorScheme: const ColorScheme.light(
        primary:   primary,
        secondary: goldBorder,
        surface:   parchmentCard,
        error:     colorRed,
        onPrimary: Colors.white,
        onSurface: inkPrimary,
      ),

      // — AppBar —
      appBarTheme: const AppBarTheme(
        backgroundColor:  parchment,
        foregroundColor:  inkPrimary,
        elevation:        0,
        centerTitle:      true,
        scrolledUnderElevation: 1,
        shadowColor:      Color(0x1AB8820F),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor:      Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontFamily:  'DM Sans',
          fontSize:    17,
          fontWeight:  FontWeight.w500,
          color:       goldLight,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: inkSecondary, size: 22),
      ),

      // — Cards —
      cardTheme: CardThemeData(
        color:     parchmentCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x26B8820F), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // — Bouton principal —
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation:       0,
          shadowColor:     Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'DM Sans',
            fontSize:   15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // — TextButton —
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontFamily: 'DM Sans',
            fontSize:   14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // — Inputs —
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: parchmentDeep,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: Color(0x26B8820F), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: goldLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: colorRed, width: 1.5),
        ),
        hintStyle:  const TextStyle(fontFamily: 'DM Sans', color: inkTertiary, fontWeight: FontWeight.w300),
        labelStyle: const TextStyle(fontFamily: 'DM Sans', color: inkTertiary),
        prefixIconColor: inkTertiary,
      ),

      // — Bottom Navigation —
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:      parchment,
        selectedItemColor:    goldLight,
        unselectedItemColor:  inkTertiary,
        elevation:            0,
        type:                 BottomNavigationBarType.fixed,
        selectedLabelStyle:   TextStyle(fontFamily: 'DM Sans', fontSize: 9,  fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontFamily: 'DM Sans', fontSize: 9,  fontWeight: FontWeight.w400),
      ),

      // — Divider —
      dividerTheme: const DividerThemeData(
        color:     Color(0x26B8820F),
        thickness: 1,
        space:     1,
      ),

      // — SnackBar —
      snackBarTheme: SnackBarThemeData(
        backgroundColor:   inkPrimary,
        contentTextStyle:  const TextStyle(fontFamily: 'DM Sans', color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior:          SnackBarBehavior.floating,
      ),

      // — Text —
      textTheme: _buildTextTheme(Brightness.light),
    );
  }

  // ══════════════════════════════════════════════
  //  THÈME SOMBRE — NAVY
  // ══════════════════════════════════════════════
  static ThemeData get darkTheme {
    const Color primary = goldDark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navy,
      primaryColor: primary,

      colorScheme: const ColorScheme.dark(
        primary:   primary,
        secondary: Color(0xFF3A4E68),
        surface:   navy3,
        error:     colorRedDark,
        onPrimary: navy,
        onSurface: snowPrimary,
      ),

      // — AppBar —
      appBarTheme: const AppBarTheme(
        backgroundColor:  navy2,
        foregroundColor:  snowPrimary,
        elevation:        0,
        centerTitle:      true,
        scrolledUnderElevation: 1,
        shadowColor:      Colors.black26,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor:      Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily:  'DM Sans',
          fontSize:    17,
          fontWeight:  FontWeight.w500,
          color:       goldDark,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: snowSecondary, size: 22),
      ),

      // — Cards —
      cardTheme: CardThemeData(
        color:     navy3,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // — Bouton principal —
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: navy,
          elevation:       0,
          shadowColor:     Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'DM Sans',
            fontSize:   15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // — TextButton —
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontFamily: 'DM Sans',
            fontSize:   14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // — Inputs —
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: navy3,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: goldDark, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: colorRedDark, width: 1.5),
        ),
        hintStyle:  const TextStyle(fontFamily: 'DM Sans', color: snowTertiary, fontWeight: FontWeight.w300),
        labelStyle: const TextStyle(fontFamily: 'DM Sans', color: snowTertiary),
        prefixIconColor: snowTertiary,
      ),

      // — Bottom Navigation —
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:      navy,
        selectedItemColor:    goldDark,
        unselectedItemColor:  snowTertiary,
        elevation:            0,
        type:                 BottomNavigationBarType.fixed,
        selectedLabelStyle:   TextStyle(fontFamily: 'DM Sans', fontSize: 9,  fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontFamily: 'DM Sans', fontSize: 9,  fontWeight: FontWeight.w400),
      ),

      // — Divider —
      dividerTheme: const DividerThemeData(
        color:     Color(0x1AFFFFFF),
        thickness: 1,
        space:     1,
      ),

      // — SnackBar —
      snackBarTheme: SnackBarThemeData(
        backgroundColor:   navy3,
        contentTextStyle:  const TextStyle(fontFamily: 'DM Sans', color: snowPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior:          SnackBarBehavior.floating,
      ),

      // — Text —
      textTheme: _buildTextTheme(Brightness.dark),
    );
  }

  // ══════════════════════════════════════════════
  //  TEXTSTYLE HELPERS
  // ══════════════════════════════════════════════

  /// TextTheme adapté au mode
  static TextTheme _buildTextTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color t1 = isDark ? snowPrimary  : inkPrimary;
    final Color t2 = isDark ? snowSecondary: inkSecondary;
    final Color t3 = isDark ? snowTertiary : inkTertiary;

    return TextTheme(
      // Grandes affiches (Cormorant Garamond)
      displayLarge:  TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 40, fontWeight: FontWeight.w600, color: t1, letterSpacing: 0.3),
      displayMedium: TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 32, fontWeight: FontWeight.w600, color: t1),
      displaySmall:  TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 26, fontWeight: FontWeight.w600, color: t1),

      // Titres (Cormorant Garamond)
      headlineLarge:  TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 24, fontWeight: FontWeight.w600, color: t1),
      headlineMedium: TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 20, fontWeight: FontWeight.w600, color: t1),
      headlineSmall:  TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 18, fontWeight: FontWeight.w500, color: t1),

      // Titres de section (DM Sans)
      titleLarge:  TextStyle(fontFamily: 'DM Sans', fontSize: 17, fontWeight: FontWeight.w500, color: t1),
      titleMedium: TextStyle(fontFamily: 'DM Sans', fontSize: 15, fontWeight: FontWeight.w500, color: t1),
      titleSmall:  TextStyle(fontFamily: 'DM Sans', fontSize: 13, fontWeight: FontWeight.w500, color: t1),

      // Corps (DM Sans)
      bodyLarge:  TextStyle(fontFamily: 'DM Sans', fontSize: 16, fontWeight: FontWeight.w400, color: t1, height: 1.6),
      bodyMedium: TextStyle(fontFamily: 'DM Sans', fontSize: 14, fontWeight: FontWeight.w400, color: t2, height: 1.5),
      bodySmall:  TextStyle(fontFamily: 'DM Sans', fontSize: 12, fontWeight: FontWeight.w300, color: t3, height: 1.4),

      // Labels / caps
      labelLarge:  TextStyle(fontFamily: 'DM Sans', fontSize: 13, fontWeight: FontWeight.w500, color: t1),
      labelMedium: TextStyle(fontFamily: 'DM Sans', fontSize: 11, fontWeight: FontWeight.w500, color: t2, letterSpacing: 0.8),
      labelSmall:  TextStyle(fontFamily: 'DM Sans', fontSize: 10, fontWeight: FontWeight.w500, color: t3, letterSpacing: 1.0),
    );
  }

  // ══════════════════════════════════════════════
  //  HELPER — couleur gold selon le contexte
  // ══════════════════════════════════════════════
  static Color gold(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? goldDark : goldLight;
  }

  /// Fond gold (fill)
  static Color goldBackground(BuildContext context) => goldFill;

  // ══════════════════════════════════════════════
  //  STYLES TEXTUEL PRÊTS À L'EMPLOI
  // ══════════════════════════════════════════════

  /// Titre d'écran (Cormorant)
  static TextStyle screenTitle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontFamily: 'Cormorant Garamond',
      fontSize:   28,
      fontWeight: FontWeight.w600,
      color:      isDark ? snowPrimary : inkPrimary,
      letterSpacing: 0.3,
    );
  }

  /// Sous-titre / description
  static TextStyle subtitle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontFamily: 'DM Sans',
      fontSize:   14,
      fontWeight: FontWeight.w300,
      color:      isDark ? snowTertiary : inkTertiary,
      height:     1.6,
    );
  }

  /// Label de section en majuscules
  static TextStyle sectionLabel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontFamily:  'DM Sans',
      fontSize:    10,
      fontWeight:  FontWeight.w500,
      color:       isDark ? snowTertiary : inkTertiary,
      letterSpacing: 1.2,
    );
  }

  // ══════════════════════════════════════════════
  //  DÉCORATIONS RÉUTILISABLES
  // ══════════════════════════════════════════════

  /// Décoration card standard
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color:        isDark ? navy3 : parchmentCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isDark ? const Color(0x1AFFFFFF) : const Color(0x26B8820F),
        width: 1,
      ),
      boxShadow: isDark
          ? null
          : [const BoxShadow(color: Color(0x0FB8820F), blurRadius: 12, offset: Offset(0, 4))],
    );
  }

  /// Décoration chip/badge doré
  static BoxDecoration goldChipDecoration(BuildContext context) {
    return BoxDecoration(
      color:        goldFill,
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: goldBorder, width: 1),
    );
  }

  /// Décoration icône action
  static BoxDecoration actionIconDecoration(BuildContext context) {
    return BoxDecoration(
      color:        goldFill,
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: goldBorder, width: 1),
    );
  }
}