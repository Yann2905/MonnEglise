/*
 * FICHIER : lib/widgets/avatar_picker.dart
 *
 * Widget réutilisable — Cercle photo de profil tappable pour les
 * formulaires d'inscription. Stocke un XFile local (non uploadé).
 * L'upload se fait à la finalisation de l'inscription.
 *
 * Compatible Web : utilise XFile + FutureBuilder<Uint8List> pour
 * afficher l'aperçu (Image.file() ne marche pas sur Web).
 */

import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import '../core/cupertino_theme.dart';
import '../services/avatar_service.dart';

class AvatarPicker extends StatelessWidget {
  final XFile? file;
  final ValueChanged<XFile?> onPicked;
  final double size;

  const AvatarPicker({
    super.key,
    required this.file,
    required this.onPicked,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    final isDark = IOSTheme.isDark(context);
    final radius = size / 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        // Pendant l'inscription, pas d'avatar existant → on n'affiche pas
        // l'option Supprimer.
        final result = await AvatarService.pickFromActionSheet(context);
        if (result?.action == AvatarPickAction.pick && result?.file != null) {
          onPicked(result!.file!);
        }
      },
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: file == null
                ? Icon(CupertinoIcons.camera_fill,
                    size: size * 0.36, color: blue)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: FutureBuilder<Uint8List>(
                      future: file!.readAsBytes(),
                      builder: (_, snap) {
                        if (!snap.hasData) {
                          return const Center(
                            child: CupertinoActivityIndicator(),
                          );
                        }
                        return Image.memory(
                          snap.data!,
                          fit: BoxFit.cover,
                          width: size,
                          height: size,
                        );
                      },
                    ),
                  ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.30,
              height: size * 0.30,
              decoration: BoxDecoration(
                color: blue,
                borderRadius: BorderRadius.circular(size * 0.15),
                border: Border.all(
                  color: IOSTheme.groupedBackground(context),
                  width: 2,
                ),
              ),
              child: Icon(
                file != null
                    ? CupertinoIcons.pencil
                    : CupertinoIcons.add,
                size: size * 0.16,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
