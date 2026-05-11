/*
 * FICHIER : lib/widgets/animated_background.dart
 *
 * Arrière-plan animé — 3 blobs flous qui flottent en boucle infinie.
 * Utilisé sur l'écran d'accueil/welcome (fond terracotta plein).
 * Version respectueuse du GPU : pas de blur très lourd, animations
 * lentes (8-12s par cycle).
 */

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';

class AnimatedBlobBackground extends StatefulWidget {
  final Color baseColor;
  final List<Color> blobColors;
  final Widget? child;

  const AnimatedBlobBackground({
    super.key,
    required this.baseColor,
    required this.blobColors,
    this.child,
  });

  @override
  State<AnimatedBlobBackground> createState() => _AnimatedBlobBackgroundState();
}

class _AnimatedBlobBackgroundState extends State<AnimatedBlobBackground>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      widget.blobColors.length,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(seconds: 9 + i * 2),
      )..repeat(),
    );
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          // Base colorée
          Positioned.fill(
            child: ColoredBox(color: widget.baseColor),
          ),
          // Blobs animés
          for (int i = 0; i < widget.blobColors.length; i++)
            AnimatedBuilder(
              animation: _ctrls[i],
              builder: (_, __) {
                final t = _ctrls[i].value;
                final angle = t * 2 * math.pi;
                // Chaque blob a une trajectoire elliptique différente
                final dx = 0.5 + 0.35 * math.cos(angle + i * 1.7);
                final dy = 0.5 + 0.40 * math.sin(angle + i * 2.1);
                return Align(
                  alignment: Alignment(dx * 2 - 1, dy * 2 - 1),
                  child: ImageFiltered(
                    imageFilter:
                        ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        color: widget.blobColors[i],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
          // Voile très léger pour adoucir
          Positioned.fill(
            child: ColoredBox(
              color: widget.baseColor.withValues(alpha: 0.15),
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}
