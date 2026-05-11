/*
 * FICHIER : lib/core/cupertino_theme.dart
 *
 * REDESIGN "MonÉglise — Bleu marine logo" :
 *
 *  PRIMAIRE      Bleu marine  #234A87   actions clés, boutons, brand
 *  SECONDAIRE    Bleu clair   #3D7CC9   accents
 *  SAUGE         Sage         #8FB04D   succès, présent, validation
 *  AQUA          Mint         #5DBFAD   info, calme
 *  AMBRE         Amber        #B6884A   avertissements doux
 *  ROUGE         Red          #DC3545   erreurs / destructifs
 *
 *  NEUTRES
 *   Texte         #1A1A1F     ~noir
 *   Sec.          #4A4A52
 *   Sépare.       #E5E5EA
 *   Fond          #FFFFFF     blanc pur
 *   Carte         #F7F7F8     gris ultra-clair
 *
 *  Polices :
 *   Titres élégants   → Cormorant Garamond (large titles, noms d'église)
 *   Corps & UI        → SF Pro Text natif iOS / Inter fallback
 */

import 'package:flutter/cupertino.dart';

class IOSTheme {
  IOSTheme._();

  // ══════════════════════════════════════════════
  //  PALETTE TERRACOTTA — Light (fond blanc, cards subtilement distinctes)
  // ══════════════════════════════════════════════
  static const Color groupedBgLight        = Color(0xFFFFFFFF); // blanc pur
  static const Color cardBgLight           = Color(0xFFF7F7F8); // gris très clair (cards)
  static const Color tertiaryBgLight       = Color(0xFFF2F2F4); // gris pour champs
  static const Color labelLight            = Color(0xFF1A1A1F); // texte ~noir
  static const Color secondaryLabelLight   = Color(0xCC4A4A52);
  static const Color tertiaryLabelLight    = Color(0x804A4A52);
  static const Color quaternaryLabelLight  = Color(0x404A4A52);
  static const Color separatorLight        = Color(0x33999999);
  static const Color placeholderLight      = Color(0x80999999);

  // ══════════════════════════════════════════════
  //  PALETTE TERRACOTTA — Dark (brun foncé chaud)
  // ══════════════════════════════════════════════
  static const Color groupedBgDark         = Color(0xFF1A1410); // brun très foncé
  static const Color cardBgDark            = Color(0xFF2A2018); // brun foncé
  static const Color tertiaryBgDark        = Color(0xFF3A2D24); // brun moyen
  static const Color labelDark             = Color(0xFFFAF1E6); // crème
  static const Color secondaryLabelDark    = Color(0xCCFAF1E6);
  static const Color tertiaryLabelDark     = Color(0x80FAF1E6);
  static const Color quaternaryLabelDark   = Color(0x40FAF1E6);
  static const Color separatorDark         = Color(0x40FAF1E6);
  static const Color placeholderDark       = Color(0x80FAF1E6);

  // ══════════════════════════════════════════════
  //  COULEURS DE MARQUE (bleu marine du logo)
  // ══════════════════════════════════════════════
  /// Primaire — bleu marine du logo
  static const Color systemBlueLight   = Color(0xFF234A87);
  static const Color systemBlueDark    = Color(0xFF5B8DD3); // bleu plus lumineux en dark

  /// Succès → sauge
  static const Color systemGreenLight  = Color(0xFF8FB04D);
  static const Color systemGreenDark   = Color(0xFFBED682);

  /// Erreur / destructif → vrai rouge système (sémantique forte)
  static const Color systemRedLight    = Color(0xFFDC3545);
  static const Color systemRedDark     = Color(0xFFE8574A);

  /// Avertissement → ambre doré (plus doux que pur orange)
  static const Color systemOrangeLight = Color(0xFFB6884A);
  static const Color systemOrangeDark  = Color(0xFFD4A86A);

  /// Info / calme → aqua mint
  static const Color systemTealLight   = Color(0xFF5DBFAD);
  static const Color systemTealDark    = Color(0xFF88D5C9);

  /// Bleu accent (anciennement coral) — pour les accents secondaires
  static const Color systemCoralLight  = Color(0xFF3D7CC9); // bleu clair logo
  static const Color systemCoralDark   = Color(0xFF7CABEC);

  static const Color systemGrayLight   = Color(0xFF8E8E93);
  static const Color systemGrayDark    = Color(0xFF8E8E93);

  // ══════════════════════════════════════════════
  //  POLICES
  // ══════════════════════════════════════════════
  /// Police d'UI / corps — SF Pro natif iOS, fallback système ailleurs.
  static const String fontFamily = '.SF Pro Text';

  /// Police élégante pour les grands titres et noms d'église.
  /// Cormorant Garamond chargée via google_fonts (importée à l'usage).
  static const String displayFontFamily = 'Cormorant Garamond';

  // ══════════════════════════════════════════════
  //  CUPERTINO THEME DATA
  // ══════════════════════════════════════════════
  static CupertinoThemeData get light => const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: systemBlueLight,
        scaffoldBackgroundColor: groupedBgLight,
        barBackgroundColor: Color(0xF2FFFFFF), // navbar translucide blanche
        textTheme: CupertinoTextThemeData(
          primaryColor: labelLight,
          textStyle: TextStyle(
            inherit: false,
            fontFamily: fontFamily,
            fontSize: 17,
            color: labelLight,
            letterSpacing: -0.41,
          ),
          navTitleTextStyle: TextStyle(
            inherit: false,
            fontFamily: fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: labelLight,
            letterSpacing: -0.41,
          ),
          navLargeTitleTextStyle: TextStyle(
            inherit: false,
            fontFamily: displayFontFamily,
            fontSize: 36,
            fontWeight: FontWeight.w600,
            color: labelLight,
            letterSpacing: 0.2,
          ),
          actionTextStyle: TextStyle(
            inherit: false,
            fontFamily: fontFamily,
            fontSize: 17,
            color: systemBlueLight,
            letterSpacing: -0.41,
          ),
        ),
      );

  static CupertinoThemeData get dark => const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: systemBlueDark,
        scaffoldBackgroundColor: groupedBgDark,
        barBackgroundColor: Color(0xF21A1410),
        textTheme: CupertinoTextThemeData(
          primaryColor: labelDark,
          textStyle: TextStyle(
            inherit: false,
            fontFamily: fontFamily,
            fontSize: 17,
            color: labelDark,
            letterSpacing: -0.41,
          ),
          navTitleTextStyle: TextStyle(
            inherit: false,
            fontFamily: fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: labelDark,
            letterSpacing: -0.41,
          ),
          navLargeTitleTextStyle: TextStyle(
            inherit: false,
            fontFamily: displayFontFamily,
            fontSize: 36,
            fontWeight: FontWeight.w600,
            color: labelDark,
            letterSpacing: 0.2,
          ),
          actionTextStyle: TextStyle(
            inherit: false,
            fontFamily: fontFamily,
            fontSize: 17,
            color: systemBlueDark,
            letterSpacing: -0.41,
          ),
        ),
      );

  // ══════════════════════════════════════════════
  //  HELPERS contextuels
  // ══════════════════════════════════════════════
  static bool isDark(BuildContext context) =>
      CupertinoTheme.brightnessOf(context) == Brightness.dark;

  static Color groupedBackground(BuildContext context) =>
      isDark(context) ? groupedBgDark : groupedBgLight;

  static Color cardBackground(BuildContext context) =>
      isDark(context) ? cardBgDark : cardBgLight;

  static Color tertiaryBackground(BuildContext context) =>
      isDark(context) ? tertiaryBgDark : tertiaryBgLight;

  static Color label(BuildContext context) =>
      isDark(context) ? labelDark : labelLight;

  static Color secondaryLabel(BuildContext context) =>
      isDark(context) ? secondaryLabelDark : secondaryLabelLight;

  static Color tertiaryLabel(BuildContext context) =>
      isDark(context) ? tertiaryLabelDark : tertiaryLabelLight;

  static Color separator(BuildContext context) =>
      isDark(context) ? separatorDark : separatorLight;

  static Color placeholder(BuildContext context) =>
      isDark(context) ? placeholderDark : placeholderLight;

  static Color systemBlue(BuildContext context) =>
      isDark(context) ? systemBlueDark : systemBlueLight;

  static Color systemGreen(BuildContext context) =>
      isDark(context) ? systemGreenDark : systemGreenLight;

  static Color systemRed(BuildContext context) =>
      isDark(context) ? systemRedDark : systemRedLight;

  // ══════════════════════════════════════════════
  //  STYLES TEXTUEL iOS
  // ══════════════════════════════════════════════

  /// Large title iOS (38pt) — Cormorant Garamond élégant
  static TextStyle largeTitle(BuildContext context) => TextStyle(
        inherit: false,
        fontFamily: displayFontFamily,
        fontSize: 38,
        fontWeight: FontWeight.w600,
        color: label(context),
        letterSpacing: 0.2,
        height: 1.1,
      );

  /// Titre 1 (32pt) — Cormorant Garamond élégant
  static TextStyle title1(BuildContext context) => TextStyle(
        inherit: false,
        fontFamily: displayFontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: label(context),
        letterSpacing: 0.2,
        height: 1.15,
      );

  /// Titre 2 (24pt) — Cormorant Garamond élégant
  static TextStyle title2(BuildContext context) => TextStyle(
        inherit: false,
        fontFamily: displayFontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: label(context),
        letterSpacing: 0.2,
        height: 1.2,
      );

  /// Titre 3 (20pt) — variante SF Pro pour les titres compacts (cards, sections)
  static TextStyle title3(BuildContext context) => TextStyle(
        inherit: false,
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: label(context),
        letterSpacing: 0.35,
      );

  /// Body (17pt) — taille de lecture standard iOS
  static TextStyle body(BuildContext context) => TextStyle(
        inherit: false,
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: label(context),
        letterSpacing: -0.41,
      );

  /// Callout (16pt)
  static TextStyle callout(BuildContext context) => TextStyle(
        inherit: false,
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: label(context),
        letterSpacing: -0.32,
      );

  /// Subhead (15pt) — sous-texte secondaire
  static TextStyle subhead(BuildContext context) => TextStyle(
        inherit: false,
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: secondaryLabel(context),
        letterSpacing: -0.24,
      );

  /// Footnote (13pt) — labels de section "INFORMATION", "CODE…"
  static TextStyle footnote(BuildContext context) => TextStyle(
        inherit: false,
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondaryLabel(context),
        letterSpacing: -0.08,
      );

  /// Caption (12pt)
  static TextStyle caption(BuildContext context) => TextStyle(
        inherit: false,
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: tertiaryLabel(context),
        letterSpacing: 0.0,
      );

  /// Section header iOS — 13pt majuscules, secondaryLabel
  static TextStyle sectionHeader(BuildContext context) => TextStyle(
        inherit: false,
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondaryLabel(context),
        letterSpacing: -0.08,
      );

  // ══════════════════════════════════════════════
  //  DÉCORATIONS iOS
  // ══════════════════════════════════════════════

  /// Cellule "inset grouped" — fond blanc, coins arrondis 10
  static BoxDecoration insetGroupedCell(BuildContext context) => BoxDecoration(
        color: cardBackground(context),
        borderRadius: BorderRadius.circular(10),
      );

  /// Champ texte iOS — fond gris clair tertiary
  static BoxDecoration textFieldDecoration(BuildContext context) =>
      BoxDecoration(
        color: tertiaryBackground(context),
        borderRadius: BorderRadius.circular(10),
      );
}
