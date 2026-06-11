/*
 * FICHIER : lib/services/avatar_service.dart
 *
 * Service avatars utilisateurs — basé sur Cloudinary (25 Go gratuits).
 *
 *  • pickFromActionSheet(context, {hasExisting}) → ActionSheet avec
 *    [Galerie / Caméra / Supprimer (rouge si hasExisting) / Annuler]
 *    Retourne un AvatarAction (pick/delete/null).
 *  • uploadAndSave(userId, xfile, oldPublicId) → upload vers Cloudinary,
 *    update users.avatar_url + avatar_public_id, supprime l'ancien fichier.
 *  • deleteAvatar(userId, oldPublicId) → supprime sur Cloudinary + remet
 *    avatar_url/avatar_public_id à NULL.
 */

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cloudinary_service.dart';

/// Résultat de l'ActionSheet — soit on a choisi une image, soit on veut
/// supprimer la photo existante, soit l'utilisateur a annulé.
enum AvatarPickAction { pick, delete }

class AvatarPickResult {
  final AvatarPickAction action;
  final XFile? file; // non-null seulement si action == pick

  const AvatarPickResult._(this.action, this.file);
  factory AvatarPickResult.delete() =>
      const AvatarPickResult._(AvatarPickAction.delete, null);
  factory AvatarPickResult.pick(XFile f) =>
      AvatarPickResult._(AvatarPickAction.pick, f);
}

enum _SheetChoice { gallery, camera, delete }

class AvatarService {
  AvatarService._();

  static final SupabaseClient _client = Supabase.instance.client;

  /// ActionSheet :
  ///  [Galerie] [Caméra]  +  [Supprimer la photo] (rouge, si hasExisting)
  ///                      +  [Annuler]
  /// Retourne `null` si annulé.
  static Future<AvatarPickResult?> pickFromActionSheet(
    BuildContext context, {
    bool hasExisting = false,
  }) async {
    final _SheetChoice? choice =
        await showCupertinoModalPopup<_SheetChoice>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Photo de profil'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, _SheetChoice.gallery),
            child: const Text('Choisir depuis la galerie'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, _SheetChoice.camera),
            child: const Text('Prendre une photo'),
          ),
          if (hasExisting)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, _SheetChoice.delete),
              child: const Text('Supprimer la photo'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
      ),
    );

    if (choice == null) return null;
    if (choice == _SheetChoice.delete) return AvatarPickResult.delete();

    final source = choice == _SheetChoice.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    final picked = await _pick(source);
    if (picked == null) return null;
    return AvatarPickResult.pick(picked);
  }

  static Future<XFile?> _pick(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      return img;
    } catch (e) {
      // ignore: avoid_print
      print('❌ AvatarService._pick: $e');
      return null;
    }
  }

  /// Upload + persistance DB.
  /// Si `oldPublicId` est fourni, l'ancien fichier est supprimé après l'upload
  /// du nouveau (best-effort).
  /// Retourne la nouvelle URL ou null en cas d'erreur.
  static Future<String?> uploadAndSave({
    required String userId,
    required XFile xfile,
    String? oldPublicId,
  }) async {
    try {
      final fileName =
          'avatar_${DateTime.now().millisecondsSinceEpoch}.${_extOf(xfile.name)}';
      final folder = 'moneglise/users/$userId';
      final shortId = 'avatar_${DateTime.now().millisecondsSinceEpoch}';

      final result = await CloudinaryService.uploadImage(
        path: xfile.path,
        bytes: await xfile.readAsBytes(),
        fileName: fileName,
        folder: folder,
        publicId: shortId,
      );

      // Cache-bust pour forcer le reload côté UI (l'URL Cloudinary contient
      // déjà un identifiant unique, mais on ajoute ?t= par sécurité)
      final urlWithBust =
          '${result.secureUrl}?t=${DateTime.now().millisecondsSinceEpoch}';

      // Update DB
      await _client.from('users').update({
        'avatar_url': urlWithBust,
        'avatar_public_id': result.publicId,
      }).eq('id', userId);

      // Supprime l'ancien fichier (best-effort)
      if (oldPublicId != null && oldPublicId.isNotEmpty) {
        unawaited(_deleteCloudinaryFile(oldPublicId, 'image'));
      }

      return urlWithBust;
    } catch (e) {
      // ignore: avoid_print
      print('❌ AvatarService.uploadAndSave: $e');
      return null;
    }
  }

  /// Supprime l'avatar : remove du Cloudinary + reset DB (avatar_url null).
  static Future<bool> deleteAvatar({
    required String userId,
    required String? publicId,
  }) async {
    try {
      // 1. Supprime sur Cloudinary (best-effort)
      if (publicId != null && publicId.isNotEmpty) {
        await _deleteCloudinaryFile(publicId, 'image');
      }
      // 2. Reset DB
      await _client.from('users').update({
        'avatar_url': null,
        'avatar_public_id': null,
      }).eq('id', userId);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ AvatarService.deleteAvatar: $e');
      return false;
    }
  }

  static Future<void> _deleteCloudinaryFile(
      String publicId, String resourceType) async {
    try {
      await _client.functions.invoke(
        'delete-cloudinary',
        body: {
          'public_id': publicId,
          'resource_type': resourceType,
        },
      );
    } catch (_) {
      // Silencieux : on accepte qu'un fichier orphelin reste si la fonction
      // est down. Pas critique.
    }
  }

  static String _extOf(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }
}
