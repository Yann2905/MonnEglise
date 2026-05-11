/*
 * FICHIER : lib/widgets/church_setup_modal.dart
 *
 * REDESIGN "iOS" — Modal de configuration de l'église :
 * — CupertinoActionSheet pour choisir galerie ou caméra
 * — CupertinoTextField arrondi pour le nom
 * — CupertinoButton bleu plein
 * — Logo upload via Supabase Storage (bucket 'churches')
 */

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import '../core/cupertino_theme.dart';
import '../providers/auth_provider.dart';

class ChurchSetupModal extends StatefulWidget {
  final VoidCallback onComplete;
  const ChurchSetupModal({super.key, required this.onComplete});

  @override
  State<ChurchSetupModal> createState() => _ChurchSetupModalState();
}

class _ChurchSetupModalState extends State<ChurchSetupModal> {
  final _churchNameController = TextEditingController();
  File? _logoFile;
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _churchNameController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════
  //  ACTIONS
  // ══════════════════════════════════════════════

  void _pickImage() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Logo de l\'église'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              await _pickFromSource(ImageSource.gallery);
            },
            child: const Text('Choisir depuis la galerie'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              await _pickFromSource(ImageSource.camera);
            },
            child: const Text('Prendre une photo'),
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

  Future<void> _pickFromSource(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (image != null && mounted) {
      setState(() => _logoFile = File(image.path));
    }
  }

  Future<void> _saveChurchInfo() async {
    final name = _churchNameController.text.trim();
    if (name.isEmpty) {
      _showAlert('Champ requis', "Veuillez entrer le nom de l'église.");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final userId =
          Provider.of<AuthProvider>(context, listen: false).currentUser!.id;
      String? logoUrl;

      if (_logoFile != null) {
        final fileName =
            'logo_${DateTime.now().millisecondsSinceEpoch}${path.extension(_logoFile!.path)}';
        final filePath = '$userId/$fileName';
        await _supabase.storage.from('churches').upload(
              filePath,
              _logoFile!,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
        logoUrl =
            _supabase.storage.from('churches').getPublicUrl(filePath);
      }

      // Crée OU met à jour l'église
      final existing = await _supabase
          .from('churches')
          .select()
          .eq('admin_id', userId)
          .maybeSingle();

      if (existing == null) {
        final inserted = await _supabase.from('churches').insert({
          'name': name,
          'logo_url': logoUrl,
          'admin_id': userId,
        }).select().single();
        // Lier l'admin à son église
        await _supabase
            .from('users')
            .update({'church_id': inserted['id']}).eq('id', userId);
      } else {
        await _supabase.from('churches').update({
          'name': name,
          if (logoUrl != null) 'logo_url': logoUrl,
        }).eq('id', existing['id']);
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      _showAlert('Erreur', 'Impossible de sauvegarder : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  // ══════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    final isDark = IOSTheme.isDark(context);

    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: IOSTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    Icon(CupertinoIcons.building_2_fill, size: 28, color: blue),
              ),
              const SizedBox(height: 14),
              Text(
                "Ton église",
                style: IOSTheme.title1(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                "Donnez un nom et un logo à votre assemblée",
                style: IOSTheme.subhead(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Logo picker
              GestureDetector(
                onTap: _isLoading ? null : _pickImage,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: IOSTheme.tertiaryBackground(context),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: _logoFile != null
                          ? blue
                          : CupertinoColors.transparent,
                      width: 2,
                    ),
                  ),
                  child: _logoFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: Image.file(_logoFile!, fit: BoxFit.cover),
                        )
                      : Icon(
                          CupertinoIcons.camera_fill,
                          size: 36,
                          color: IOSTheme.tertiaryLabel(context),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _logoFile != null ? 'Toucher pour changer' : 'Ajouter un logo',
                style: IOSTheme.footnote(context).copyWith(color: blue),
              ),
              const SizedBox(height: 22),

              // Nom de l'église
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: IOSTheme.tertiaryBackground(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CupertinoTextField(
                  controller: _churchNameController,
                  enabled: !_isLoading,
                  placeholder: "Nom de l'église",
                  decoration: const BoxDecoration(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(CupertinoIcons.building_2_fill,
                        size: 18, color: IOSTheme.tertiaryLabel(context)),
                  ),
                  style: IOSTheme.body(context),
                  placeholderStyle: IOSTheme.body(context).copyWith(
                    color: IOSTheme.placeholder(context),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ce nom sera visible par tous vos membres.',
                style: IOSTheme.caption(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Bouton Valider (pas de "Plus tard" — création obligatoire)
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: blue,
                  disabledColor: blue.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  borderRadius: BorderRadius.circular(16),
                  onPressed: _isLoading ? null : _saveChurchInfo,
                  child: _isLoading
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white)
                      : const Text(
                          'Créer mon église',
                          style: TextStyle(
                            inherit: false,
                            fontFamily: IOSTheme.fontFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
