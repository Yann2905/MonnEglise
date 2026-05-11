/*
 * FICHIER : lib/screens/shared/sermon_form_screen.dart
 *
 * Formulaire admin pour créer ou modifier une prédication.
 * — Thème (texte)
 * — Versets associés (texte multiligne)
 * — Date du dimanche
 * — Audio MP3 (file_picker → Supabase Storage bucket `sermons`)
 */

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/cupertino_theme.dart';
import '../../models/sermon_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ios_date_picker_field.dart';

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
  File? _audioFile;
  String? _audioFileName;
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
      );
      if (res == null) return;
      final picked = res.files.single;
      if (picked.path == null) return;

      // Sécurité : vérifie l'extension côté client
      if (!picked.name.toLowerCase().endsWith('.mp3')) {
        _showAlert('Format non supporté',
            'Seuls les fichiers MP3 sont acceptés.');
        return;
      }

      if (mounted) {
        setState(() {
          _audioFile = File(picked.path!);
          _audioFileName = picked.name;
        });
      }
    } catch (_) {}
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

      // Upload audio si nouveau fichier
      if (_audioFile != null) {
        final fileName =
            'sermon_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final filePath = '$churchId/$fileName';
        await _supabase.storage.from('sermons').upload(
              filePath,
              _audioFile!,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
                contentType: 'audio/mpeg',
              ),
            );
        audioUrl =
            _supabase.storage.from('sermons').getPublicUrl(filePath);
      }

      final body = {
        'church_id':   churchId,
        'theme':       theme,
        'verses':      _versesCtrl.text.trim().isEmpty
            ? null
            : _versesCtrl.text.trim(),
        'audio_url':   audioUrl,
        'sermon_date': _date.toIso8601String(),
      };

      if (widget.existing == null) {
        await _supabase.from('sermons').insert(body);
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
                        _audioFile != null ||
                                widget.existing?.hasAudio == true
                            ? CupertinoIcons.music_note
                            : CupertinoIcons.cloud_upload,
                        color: blue,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _audioFile != null
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
