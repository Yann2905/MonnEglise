/*
 * FICHIER : lib/screens/shared/sermon_form_screen.dart
 *
 * Formulaire admin pour créer ou modifier une prédication.
 * — Thème (texte)
 * — Versets associés (texte multiligne)
 * — Date du dimanche
 * — Audio MP3 (file_picker → Supabase Storage bucket `sermons`)
 */

import 'dart:io' show File;
import 'dart:typed_data';
import 'package:dio/dio.dart' show CancelToken, DioException, DioExceptionType;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/cupertino_theme.dart';
import '../../models/sermon_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/ios_date_picker_field.dart';
import '../../widgets/upload_progress_dialog.dart';

class SermonFormScreen extends StatefulWidget {
  final SermonModel? existing;
  const SermonFormScreen({super.key, this.existing});

  @override
  State<SermonFormScreen> createState() => _SermonFormScreenState();
}

class _SermonFormScreenState extends State<SermonFormScreen> {
  final _supabase = Supabase.instance.client;
  late final TextEditingController _themeCtrl;
  late final TextEditingController _versesCtrl;
  late DateTime _date;
  // Sur mobile : on garde la référence File (rapide, fiable, pas de copie mémoire)
  File? _audioFile;
  // Sur web : on doit travailler avec les bytes
  Uint8List? _audioBytes;
  String? _audioFileName;

  bool get _hasAudioPicked => _audioFile != null || _audioBytes != null;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _themeCtrl = TextEditingController(text: widget.existing?.theme ?? '');
    _versesCtrl =
        TextEditingController(text: widget.existing?.verses ?? '');
    _date = widget.existing?.sermonDate ?? _lastSunday();
  }

  DateTime _lastSunday() {
    final now = DateTime.now();
    final daysSinceSunday = (now.weekday - DateTime.sunday) % 7;
    return DateTime(now.year, now.month, now.day - daysSinceSunday);
  }

  @override
  void dispose() {
    _themeCtrl.dispose();
    _versesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3'],
        allowMultiple: false,
        withData: kIsWeb, // bytes nécessaires uniquement sur web
      );
      if (res == null) return;
      final picked = res.files.single;

      // Sécurité : vérifie l'extension côté client
      if (!picked.name.toLowerCase().endsWith('.mp3')) {
        _showAlert('Format non supporté',
            'Seuls les fichiers MP3 sont acceptés.');
        return;
      }

      // Stratégie selon plateforme :
      //  • Mobile : stocke File(path) — ancien chemin éprouvé
      //  • Web    : stocke bytes (path est null en web)
      if (!kIsWeb && picked.path != null) {
        if (mounted) {
          setState(() {
            _audioFile = File(picked.path!);
            _audioBytes = null;
            _audioFileName = picked.name;
          });
        }
      } else if (picked.bytes != null) {
        if (mounted) {
          setState(() {
            _audioFile = null;
            _audioBytes = picked.bytes;
            _audioFileName = picked.name;
          });
        }
      } else {
        _showAlert('Erreur',
            "Impossible de lire le fichier. Réessaie depuis un autre emplacement.");
        return;
      }
    } catch (e) {
      if (mounted) _showAlert('Erreur', "Sélection impossible : $e");
    }
  }

  void _showAlert(String title, String desc) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(desc),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final theme = _themeCtrl.text.trim();
    if (theme.isEmpty) {
      _showAlert('Champ requis', 'Le thème est obligatoire.');
      return;
    }

    final user =
        Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    final churchId = user.churchId.isNotEmpty ? user.churchId : user.id;

    setState(() => _saving = true);
    try {
      String? audioUrl = widget.existing?.audioUrl;
      String? audioPublicId = widget.existing?.audioPublicId;

      // Upload audio sur Cloudinary AVEC modal de progression + annulation
      if (_hasAudioPicked) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'sermon_$ts.mp3';

        // On génère le public_id à l'avance pour pouvoir le supprimer
        // sur Cloudinary même en cas d'annulation mi-upload.
        final folder = 'moneglise/$churchId/sermons';
        final shortId = 'sermon_$ts';
        final fullPublicId = '$folder/$shortId';

        final progressCtrl = UploadProgressController();
        final cancelToken = CancelToken();
        bool dialogClosed = false;

        // Affiche le modal de progression
        if (!mounted) return;
        // ignore: unawaited_futures
        showCupertinoDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => UploadProgressDialog(
            fileName: _audioFileName ?? fileName,
            controller: progressCtrl,
            onCancel: () {
              cancelToken.cancel('user_cancel');
            },
          ),
        );

        try {
          final result = await CloudinaryService.uploadAudio(
            path: _audioFile?.path,
            bytes: _audioBytes,
            fileName: fileName,
            folder: folder,
            publicId: shortId, // ← Cloudinary préfixera avec le folder
            cancelToken: cancelToken,
            onProgress: (sent, total) {
              progressCtrl.update(sent, total);
            },
          );
          audioUrl = result.secureUrl;
          audioPublicId = result.publicId;
          progressCtrl.setPhase('Finalisation…');
        } on DioException catch (e) {
          if (mounted && !dialogClosed) {
            Navigator.of(context, rootNavigator: true).pop();
            dialogClosed = true;
          }
          if (e.type == DioExceptionType.cancel) {
            // Upload annulé par l'utilisateur :
            // best-effort cleanup → on demande à Cloudinary de supprimer
            // le fichier au cas où il aurait eu le temps d'être stocké.
            // Si le fichier n'existe pas, la fonction renvoie un not-found,
            // qu'on ignore silencieusement.
            try {
              await _supabase.functions.invoke(
                'delete-cloudinary',
                body: {
                  'public_id': fullPublicId,
                  'resource_type': 'video',
                },
              );
            } catch (_) {}
            setState(() => _saving = false);
            return;
          }
          rethrow;
        } finally {
          // Ferme le modal si toujours ouvert
          if (mounted && !dialogClosed) {
            Navigator.of(context, rootNavigator: true).pop();
            dialogClosed = true;
          }
        }
      }

      final body = {
        'church_id':       churchId,
        'theme':           theme,
        'verses':          _versesCtrl.text.trim().isEmpty
            ? null
            : _versesCtrl.text.trim(),
        'audio_url':       audioUrl,
        'audio_public_id': audioPublicId,
        'sermon_date':     _date.toIso8601String(),
      };

      if (widget.existing == null) {
        await _supabase.from('sermons').insert(body);

        // ── Notif "Nouvelle prédication" à tous les membres de l'église ──
        await _notifyMembersNewSermon(
          churchId: churchId,
          senderId: user.id,
          theme: theme,
          hasAudio: audioUrl != null,
        );
      } else {
        await _supabase
            .from('sermons')
            .update(body)
            .eq('id', widget.existing!.id);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showAlert('Erreur', "Impossible d'enregistrer : $e");
      }
    }
  }

  /// Envoie une notif "La prédication est disponible" à tous les membres
  /// de l'église — en in-app (`notifications`) + en push (`send-push`).
  /// Best-effort : si ça échoue, la création du sermon reste valide.
  Future<void> _notifyMembersNewSermon({
    required String churchId,
    required String senderId,
    required String theme,
    required bool hasAudio,
  }) async {
    try {
      // 1. Récupère tous les users de l'église SAUF l'admin expéditeur
      final res = await _supabase
          .from('users')
          .select('id')
          .eq('church_id', churchId);
      final recipients = (res as List)
          .map((u) => u['id'] as String)
          .where((id) => id != senderId)
          .toSet();

      if (recipients.isEmpty) return;

      const title = 'MonÉglise';
      final message = hasAudio
          ? 'La prédication "$theme" est disponible.'
          : 'Une nouvelle prédication "$theme" a été ajoutée.';

      // 2. Insert in-app notifications
      // ⚠️ On utilise 'system' (déjà autorisé par le CHECK constraint de la DB)
      // Pour distinguer 'sermon' dans le futur : exécuter
      // database/migration_notif_type_sermon.sql puis changer pour
      // AppConstants.notificationTypeSermon.
      final rows = recipients
          .map((id) => {
                'title': title,
                'message': message,
                'type': AppConstants.notificationTypeSystem,
                'sender_id': senderId,
                'receiver_id': id,
                'is_read': false,
              })
          .toList();
      await _supabase.from('notifications').insert(rows);

      // 3. Push FCM (best-effort)
      try {
        await _supabase.functions.invoke(
          'send-push',
          body: {
            'title': title,
            'message': message,
            'user_ids': recipients.toList(),
            'data': {'type': AppConstants.notificationTypeSermon},
          },
        );
      } catch (_) {
        // Edge function KO → on garde au moins l'in-app
      }
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ _notifyMembersNewSermon: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    final isEditing = widget.existing != null;

    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(isEditing ? 'Modifier' : 'Nouvelle prédication',
            style: TextStyle(
              inherit: false,
              fontFamily: IOSTheme.fontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: IOSTheme.label(context),
            )),
        backgroundColor:
            IOSTheme.groupedBackground(context).withValues(alpha: 0.9),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: _saving
              ? const CupertinoActivityIndicator()
              : Text(
                  isEditing ? 'Enregistrer' : 'Créer',
                  style: TextStyle(
                    inherit: false,
                    fontFamily: IOSTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: blue,
                  ),
                ),
        ),
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _label('THÈME'),
              const SizedBox(height: 8),
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: IOSTheme.tertiaryBackground(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CupertinoTextField(
                  controller: _themeCtrl,
                  placeholder: 'Ex: La grâce de Dieu',
                  decoration: const BoxDecoration(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(CupertinoIcons.bookmark_fill,
                        size: 18,
                        color: IOSTheme.tertiaryLabel(context)),
                  ),
                  style: IOSTheme.body(context),
                  placeholderStyle: IOSTheme.body(context).copyWith(
                    color: IOSTheme.placeholder(context),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              _label('VERSETS ASSOCIÉS'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: IOSTheme.tertiaryBackground(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CupertinoTextField(
                  controller: _versesCtrl,
                  placeholder: 'Ex: Romains 8:28-30',
                  maxLines: 3,
                  decoration: const BoxDecoration(),
                  padding: const EdgeInsets.all(14),
                  style: IOSTheme.body(context),
                  placeholderStyle: IOSTheme.body(context).copyWith(
                    color: IOSTheme.placeholder(context),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              _label('DATE DE LA PRÉDICATION'),
              const SizedBox(height: 8),
              IOSDatePickerField(
                value: _date,
                onChanged: (d) => setState(() => _date = d),
                minimumDate: DateTime(2020),
                maximumDate:
                    DateTime.now().add(const Duration(days: 30)),
              ),

              const SizedBox(height: 20),

              _label('AUDIO MP3 (FACULTATIF)'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickAudio,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: IOSTheme.tertiaryBackground(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasAudioPicked ||
                                widget.existing?.hasAudio == true
                            ? CupertinoIcons.music_note
                            : CupertinoIcons.cloud_upload,
                        color: blue,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _hasAudioPicked
                              ? _audioFileName ?? 'Fichier audio sélectionné'
                              : widget.existing?.hasAudio == true
                                  ? 'Audio existant — toucher pour remplacer'
                                  : 'Toucher pour choisir un MP3',
                          style: IOSTheme.body(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(CupertinoIcons.chevron_right,
                          size: 14, color: IOSTheme.tertiaryLabel(context)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text,
            style: IOSTheme.sectionHeader(context)
                .copyWith(fontSize: 12, letterSpacing: 0.6)),
      );
}
