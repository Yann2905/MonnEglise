/*
 * FICHIER : lib/screens/auth/register_choice_screen.dart
 *
 * REDESIGN "Terracotta" — Choix Admin / Membre :
 * — Back arrow + grand titre Cormorant "Bienvenue parmi nous"
 * — 2 cartes empilées format hero :
 *     • ADMINISTRATEUR — accent terracotta, icône bouclier
 *     • MEMBRE         — accent sauge, icône groupe
 * — Lien "Déjà inscrit ? Se connecter" en bas
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/cupertino_theme.dart';

class RegisterChoiceScreen extends StatelessWidget {
  const RegisterChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context); // terracotta
    final isDark = IOSTheme.isDark(context);

    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  // Back arrow
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.canPop(context)
                          ? Navigator.pop(context)
                          : Navigator.pushReplacementNamed(context, '/'),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          CupertinoIcons.chevron_left,
                          color: IOSTheme.label(context),
                          size: 26,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Titre Cormorant
                  Text(
                    'Bienvenue\nparmi nous',
                    style: IOSTheme.largeTitle(context),
                  )
                      .animate()
                      .fadeIn(duration: 350.ms)
                      .slideY(
                          begin: 0.15,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOutCubic),

                  const SizedBox(height: 10),

                  // Sous-titre
                  Text(
                    'Tu es ?',
                    style: IOSTheme.body(context).copyWith(
                      color: IOSTheme.secondaryLabel(context),
                      height: 1.4,
                    ),
                  )
                      .animate(delay: 100.ms)
                      .fadeIn(duration: 350.ms),

                  const SizedBox(height: 32),

                  // Carte Admin
                  _RoleCard(
                    icon: CupertinoIcons.shield_lefthalf_fill,
                    title: 'Administrateur',
                    subtitle: 'Pasteur',
                    description:
                        'Crée et gère ton église, tes membres et tes familles.',
                    accent: blue, // terracotta
                    bgAlpha: isDark ? 0.20 : 0.12,
                    onTap: () =>
                        Navigator.pushNamed(context, '/register-admin'),
                  )
                      .animate(delay: 200.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(
                          begin: 0.15,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOutCubic),

                  const SizedBox(height: 14),

                  // Carte Membre
                  _RoleCard(
                    icon: CupertinoIcons.person_2_fill,
                    title: 'Membre',
                    subtitle: 'Fidèle',
                    description:
                        'Rejoins une assemblée existante avec son code d\'invitation.',
                    accent: IOSTheme.systemGreen(context), // sauge
                    bgAlpha: isDark ? 0.20 : 0.13,
                    onTap: () =>
                        Navigator.pushNamed(context, '/register-member'),
                  )
                      .animate(delay: 320.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(
                          begin: 0.15,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOutCubic),

                  const SizedBox(height: 36),

                  // Lien connexion
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Déjà inscrit ? ',
                          style: IOSTheme.footnote(context),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: () =>
                              Navigator.pushReplacementNamed(context, '/login'),
                          child: Text(
                            'Se connecter',
                            style: TextStyle(
                              inherit: false,
                              fontFamily: IOSTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate(delay: 450.ms)
                      .fadeIn(duration: 350.ms),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  CARTE DE RÔLE
// ══════════════════════════════════════════════
class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final Color accent;
  final double bgAlpha;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.accent,
    required this.bgAlpha,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );
  late final Animation<double> _scale =
      Tween<double>(begin: 1.0, end: 0.97).animate(
    CurvedAnimation(parent: _press, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: widget.bgAlpha),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              // Icône
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withValues(
                      alpha: IOSTheme.isDark(context) ? 0.18 : 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 32),
              ),
              const SizedBox(width: 18),
              // Texte
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Petit label
                    Text(
                      widget.subtitle.toUpperCase(),
                      style: TextStyle(
                        inherit: false,
                        fontFamily: IOSTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontFamily: IOSTheme.displayFontFamily,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: IOSTheme.label(context),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.description,
                      style: IOSTheme.footnote(context).copyWith(
                        color: IOSTheme.label(context).withValues(alpha: 0.75),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: widget.accent.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
