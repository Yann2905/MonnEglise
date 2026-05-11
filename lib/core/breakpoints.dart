/*
 * FICHIER : lib/core/breakpoints.dart
 *
 * Constantes et helpers pour le responsive design.
 *
 *  PHONE   < 600  px de largeur (smartphones)
 *  TABLET  600 — 1024  (tablettes portrait)
 *  WIDE    > 1024 (tablettes paysage / desktop)
 *
 *  Largeurs MAX recommandées pour le contenu :
 *   — Forms/auth   : 480 px (lecture confortable, ne s'étire pas)
 *   — Dashboards   : 720 px (assez large pour 2 colonnes, pas plus)
 *   — Détail       : 640 px
 *   — Modals       : 460 px
 */

import 'package:flutter/cupertino.dart';

class Breakpoints {
  Breakpoints._();

  static const double phone   = 600;
  static const double tablet  = 1024;

  static bool isPhone(BuildContext context)  =>
      MediaQuery.of(context).size.width < phone;
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= phone &&
      MediaQuery.of(context).size.width < tablet;
  static bool isWide(BuildContext context)   =>
      MediaQuery.of(context).size.width >= tablet;

  // Max widths
  static const double maxAuthWidth      = 480;
  static const double maxDashboardWidth = 720;
  static const double maxDetailWidth    = 640;
  static const double maxModalWidth     = 460;

  // Padding horizontal selon écran
  static double horizontalPadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < phone) return 20;
    if (w < tablet) return 28;
    return 32;
  }

  /// Combien de colonnes dans une grille de stats
  static int statGridColumns(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < phone) return 2;       // 2 colonnes sur phone
    if (w < tablet) return 4;      // 4 sur tablette portrait
    return 4;                      // 4 sur paysage / desktop
  }
}

/// Wrapper qui centre le contenu avec une largeur max raisonnable.
/// À utiliser autour du body de chaque écran pour qu'il reste joli sur tablette.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.maxAuthWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
