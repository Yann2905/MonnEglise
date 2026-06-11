/*
 * FICHIER : lib/widgets/sermon_audio_hero.dart
 *
 * Hero card terracotta pour la dernière prédication AVEC AUDIO.
 * — Affiche thème + date + durée
 * — 2 boutons : Écouter (push détail) / Télécharger (browser)
 *
 * À utiliser uniquement quand sermon.hasAudio == true.
 * Si pas d'audio → ne pas afficher de hero du tout.
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/cupertino_theme.dart';
import '../models/sermon_model.dart';

class SermonAudioHero extends StatelessWidget {
  final SermonModel sermon;
  final VoidCallback onListen;
  final String? eyebrow; // ex: "DERNIÈRE PRÉDICATION" / "NOUVELLE PRÉDICATION"

  const SermonAudioHero({
    super.key,
    required this.sermon,
    required this.onListen,
    this.eyebrow,
  });

  String _format(DateTime d) {
    const months = [
      'janv.','févr.','mars','avr.','mai','juin','juil.','août',
      'sept.','oct.','nov.','déc.'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _download() async {
    final url = sermon.audioUrl;
    if (url == null) return;
    final base = Uri.tryParse(url);
    if (base == null) return;
    final uri = base.replace(
      queryParameters: {
        ...base.queryParameters,
        'download': 'true',
      },
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // silencieux — le widget n'a pas accès à un Scaffold pour montrer un toast
    }
  }

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context); // terracotta
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: blue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow
          Text(
            (eyebrow ?? 'PRÉDICATION').toUpperCase(),
            style: TextStyle(
              inherit: false,
              fontFamily: IOSTheme.fontFamily,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.white.withValues(alpha: 0.85),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          // Thème (Cormorant)
          Text(
            sermon.theme,
            style: TextStyle(
              fontFamily: IOSTheme.displayFontFamily,
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
              letterSpacing: 0.2,
              height: 1.15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Date + durée
          Row(
            children: [
              Icon(CupertinoIcons.calendar,
                  size: 12,
                  color:
                      CupertinoColors.white.withValues(alpha: 0.85)),
              const SizedBox(width: 4),
              Text(
                _format(sermon.sermonDate),
                style: TextStyle(
                  inherit: false,
                  fontFamily: IOSTheme.fontFamily,
                  fontSize: 12,
                  color: CupertinoColors.white.withValues(alpha: 0.85),
                ),
              ),
              if (sermon.formattedDuration != null) ...[
                const SizedBox(width: 8),
                Icon(CupertinoIcons.clock,
                    size: 12,
                    color: CupertinoColors.white.withValues(alpha: 0.85)),
                const SizedBox(width: 4),
                Text(
                  sermon.formattedDuration!,
                  style: TextStyle(
                    inherit: false,
                    fontFamily: IOSTheme.fontFamily,
                    fontSize: 12,
                    color: CupertinoColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // 2 boutons : Écouter / Télécharger
          Row(
            children: [
              Expanded(
                child: _HeroAction(
                  icon: CupertinoIcons.play_arrow_solid,
                  label: 'Écouter',
                  filled: true,
                  accent: blue,
                  onTap: onListen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroAction(
                  icon: CupertinoIcons.cloud_download,
                  label: 'Télécharger',
                  filled: false,
                  accent: blue,
                  onTap: _download,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(
            begin: 0.1,
            end: 0,
            duration: 400.ms,
            curve: Curves.easeOutCubic);
  }
}

class _HeroAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final Color accent;
  final VoidCallback onTap;

  const _HeroAction({
    required this.icon,
    required this.label,
    required this.filled,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled
              ? CupertinoColors.white
              : CupertinoColors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: filled
              ? null
              : Border.all(
                  color: CupertinoColors.white.withValues(alpha: 0.4),
                  width: 1,
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: filled ? accent : CupertinoColors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                inherit: false,
                fontFamily: IOSTheme.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: filled ? accent : CupertinoColors.white,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
