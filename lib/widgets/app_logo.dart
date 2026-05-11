/*
 * FICHIER : lib/widgets/app_logo.dart
 *
 * Logo MonÉglise — affiche assets/images/logo.png en zoomant légèrement
 * (1.10x) pour rogner les éventuels bords blancs du PNG d'origine.
 * Coins arrondis configurables.
 */

import 'package:flutter/cupertino.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final double radius;

  /// Facteur d'agrandissement de l'image dans le container — sert à
  /// rogner les bords externes du PNG (espaces blancs si présents).
  final double cropZoom;

  const AppLogo({
    super.key,
    this.size = 120,
    double? radius,
    this.cropZoom = 1.12,
  }) : radius = radius ?? size * 0.23;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: OverflowBox(
            maxWidth: size * cropZoom,
            maxHeight: size * cropZoom,
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: size,
                height: size,
                color: const Color(0xFF234A87),
                child: const Icon(
                  CupertinoIcons.building_2_fill,
                  color: CupertinoColors.white,
                  size: 56,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
