/*
 * FICHIER : lib/screens/shared/sermon_detail_screen.dart
 *
 * Détail d'une prédication — thème, versets, date, player audio.
 * — Admin : bouton "..." dans la nav bar pour Modifier / Supprimer
 * — Membre : juste lecture
 */

import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/cupertino_theme.dart';
import '../../models/sermon_model.dart';
import '../../widgets/audio_player_widget.dart';

class SermonDetailScreen extends StatelessWidget {
  final SermonModel sermon;
  final bool isAdmin;

  const SermonDetailScreen({
    super.key,
    required this.sermon,
    required this.isAdmin,
  });

  String _format(DateTime d) {
    const days = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
    const months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  void _showActions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(sermon.theme),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, 'edit');
            },
            child: const Text('Modifier'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Supprimer "${sermon.theme}" ?'),
        content: const Text(
            'Voulez-vous vraiment supprimer cette prédication ? Le fichier audio sera également supprimé. Cette action est irréversible.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              final supa = Supabase.instance.client;
              try {
                // 1. Best-effort : supprime le fichier audio sur Cloudinary
                //    (via Edge Function qui possède le secret API)
                final publicId = sermon.audioPublicId;
                if (publicId != null && publicId.isNotEmpty) {
                  try {
                    await supa.functions.invoke(
                      'delete-cloudinary',
                      body: {
                        'public_id': publicId,
                        'resource_type': 'video',
                      },
                    );
                  } catch (_) {
                    // Edge Function indisponible → on continue quand même
                    // (le fichier restera orphelin, à nettoyer manuellement)
                  }
                }
                // 2. Supprime la row DB
                await supa.from('sermons').delete().eq('id', sermon.id);
                if (context.mounted) Navigator.pop(context, 'deleted');
              } catch (_) {}
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Prédication',
            style: TextStyle(
              inherit: false,
              fontFamily: IOSTheme.fontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: IOSTheme.label(context),
            )),
        backgroundColor:
            IOSTheme.groupedBackground(context).withValues(alpha: 0.9),
        trailing: isAdmin
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showActions(context),
                child: Icon(CupertinoIcons.ellipsis_circle,
                    color: IOSTheme.systemBlue(context), size: 26),
              )
            : null,
      ),
      child: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // Header
            Text(sermon.theme, style: IOSTheme.title1(context)),
            const SizedBox(height: 6),
            Text(_format(sermon.sermonDate),
                style: IOSTheme.subhead(context)),
            const SizedBox(height: 24),

            // Player audio
            if (sermon.hasAudio)
              AudioPlayerWidget(
                url: sermon.audioUrl!,
                title: sermon.theme,
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: IOSTheme.cardBackground(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.speaker_slash,
                        color: IOSTheme.tertiaryLabel(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Aucun audio attaché',
                          style: IOSTheme.body(context).copyWith(
                              color: IOSTheme.secondaryLabel(context))),
                    ),
                  ],
                ),
              ),

            // Versets
            if (sermon.verses != null && sermon.verses!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('VERSETS',
                    style: IOSTheme.sectionHeader(context)
                        .copyWith(fontSize: 12, letterSpacing: 0.6)),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: IOSTheme.cardBackground(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(sermon.verses!,
                    style: IOSTheme.body(context).copyWith(height: 1.5)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
