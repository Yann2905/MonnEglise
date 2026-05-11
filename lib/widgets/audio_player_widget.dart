/*
 * FICHIER : lib/widgets/audio_player_widget.dart
 *
 * Player audio iOS-style basé sur just_audio.
 * — Bouton Play/Pause central
 * — Barre de progression interactive (seek)
 * — Affichage temps écoulé / temps total
 * — Bouton "Télécharger" qui ouvre l'URL dans le navigateur
 */

import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/cupertino_theme.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  final String? title;

  const AudioPlayerWidget({
    super.key,
    required this.url,
    this.title,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final _player = AudioPlayer();
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setUrl(widget.url);
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: IOSTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle_fill,
                color: IOSTheme.systemRed(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Audio indisponible',
                style: IOSTheme.body(context),
              ),
            ),
          ],
        ),
      );
    }

    if (!_initialized) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: IOSTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IOSTheme.cardBackground(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Position + Total + Bouton télécharger
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (ctx, snap) {
              final pos = snap.data ?? Duration.zero;
              final total = _player.duration ?? Duration.zero;
              final fraction = total.inMilliseconds == 0
                  ? 0.0
                  : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
              return Column(
                children: [
                  // Slider seek
                  CupertinoSlider(
                    value: fraction,
                    onChanged: (v) {
                      if (total.inMilliseconds > 0) {
                        _player.seek(Duration(
                            milliseconds: (v * total.inMilliseconds).toInt()));
                      }
                    },
                    activeColor: blue,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(pos), style: IOSTheme.caption(context)),
                        Text(_fmt(total), style: IOSTheme.caption(context)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 8),

          // Boutons : Play/Pause + Download
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 44),
              const Spacer(),
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (ctx, snap) {
                  final state = snap.data;
                  final processing = state?.processingState;
                  final playing = state?.playing ?? false;
                  if (processing == ProcessingState.loading ||
                      processing == ProcessingState.buffering) {
                    return const SizedBox(
                      width: 56,
                      height: 56,
                      child: Center(child: CupertinoActivityIndicator()),
                    );
                  }
                  return GestureDetector(
                    onTap: () {
                      if (playing) {
                        _player.pause();
                      } else {
                        if (processing == ProcessingState.completed) {
                          _player.seek(Duration.zero);
                        }
                        _player.play();
                      }
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: blue,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Icon(
                        playing
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        color: CupertinoColors.white,
                        size: 26,
                      ),
                    ),
                  );
                },
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _download,
                child: Icon(
                  CupertinoIcons.cloud_download,
                  color: blue,
                  size: 26,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
