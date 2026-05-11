/*
 * FICHIER : lib/services/avatar_service.dart
 *
 * Helpers — pick et upload d'une photo de profil dans Supabase Storage,
 * puis update users.avatar_url.
 *
 * Compatible Web + mobile : on lit les bytes via XFile.readAsBytes()
 * (qui marche partout) puis on appelle uploadBinary() côté Supabase.
 * Évite l'usage de `File()` qui ne marche pas sur Web.
 */

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarService {
  AvatarService._();

  static final SupabaseClient _client = Supabase.instance.client;

  /// Affiche une action sheet Cupertino et retourne le `XFile` choisi (ou null).
  /// L'option "Caméra" n'est pas proposée sur Web (non supportée par le browser
  /// via image_picker dans la plupart des cas).
  static Future<XFile?> pickFromActionSheet(BuildContext context) async {
    final completer = Completer<XFile?>();

    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Photo de profil'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              if (!completer.isCompleted) {
                completer.complete(await _pick(ImageSource.gallery));
              }
            },
            child: const Text('Choisir depuis la galerie'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              if (!completer.isCompleted) {
                completer.complete(await _pick(ImageSource.camera));
              }
            },
            child: const Text('Prendre une photo'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () {
            Navigator.pop(ctx);
            if (!completer.isCompleted) completer.complete(null);
          },
          child: const Text('Annuler'),
        ),
      ),
    );

    if (!completer.isCompleted) completer.complete(null);
    return completer.future;
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
      return img; // XFile ou null — fonctionne sur web et mobile
    } catch (e) {
      // ignore: avoid_print
      print('❌ AvatarService._pick: $e');
      return null;
    }
  }

  /// Upload binaire sur Supabase Storage (bucket `avatars`) puis update
  /// `users.avatar_url`. Retourne la nouvelle URL publique, ou null en cas
  /// d'échec.
  ///
  /// Compatible Web : on n'utilise PAS `File(xfile.path)` (qui crashe sur web).
  /// On lit les bytes via `xfile.readAsBytes()` et on appelle `uploadBinary()`.
  static Future<String?> uploadAndSave({
    required String userId,
    required XFile xfile,
  }) async {
    try {
      // Détermine l'extension à partir du mime ou du nom
      String ext = 'jpg';
      final name = xfile.name.toLowerCase();
      if (name.endsWith('.png')) {
        ext = 'png';
      } else if (name.endsWith('.webp')) {
        ext = 'webp';
      } else if (name.endsWith('.jpeg') || name.endsWith('.jpg')) {
        ext = 'jpg';
      }

      final fileName =
          'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final filePath = '$userId/$fileName';

      // Lit les bytes — marche sur web ET mobile
      final bytes = await xfile.readAsBytes();

      await _client.storage.from('avatars').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: 'image/$ext',
            ),
          );

      final url = _client.storage.from('avatars').getPublicUrl(filePath);

      // Cache-bust : on ajoute un timestamp à l'URL pour forcer le reload
      // du widget Image après upload
      final urlWithBust = '$url?t=${DateTime.now().millisecondsSinceEpoch}';

      await _client
          .from('users')
          .update({'avatar_url': urlWithBust}).eq('id', userId);

      return urlWithBust;
    } on StorageException catch (e) {
      // ignore: avoid_print
      print('❌ AvatarService — StorageException: ${e.message} '
          '(statusCode=${e.statusCode})');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('❌ AvatarService.uploadAndSave: $e');
      return null;
    }
  }
}
