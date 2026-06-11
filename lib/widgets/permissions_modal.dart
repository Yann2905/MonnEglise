/*
 * FICHIER : lib/widgets/permissions_modal.dart
 *
 * Modal affichée après inscription, demande UNIQUEMENT la permission
 * notifications (les permissions photo/caméra sont déclenchées
 * contextuellement par image_picker lors du 1er tap sur l'avatar).
 *
 * Sur Android 13+ les notifs nécessitent POST_NOTIFICATIONS explicitement.
 */

import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/cupertino_theme.dart';

class PermissionsModal extends StatelessWidget {
  /// Callback appelé une fois la demande traitée (acceptée ou refusée).
  final VoidCallback? onDone;

  const PermissionsModal({super.key, this.onDone});

  Future<void> _request(BuildContext context) async {
    try {
      await Permission.notification.request();
    } catch (_) {}
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      onDone?.call();
    }
  }

  void _skip(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
    onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        decoration: BoxDecoration(
          color: IOSTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: blue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.bell_fill, color: blue, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              'Restez informé',
              style: IOSTheme.title2(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Activez les notifications pour recevoir les annonces, prédications et messages du pasteur en temps réel.",
              style: IOSTheme.body(context).copyWith(
                color: IOSTheme.secondaryLabel(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: blue,
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: () => _request(context),
                child: const Text(
                  'Autoriser',
                  style: TextStyle(
                    inherit: false,
                    fontFamily: IOSTheme.fontFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              onPressed: () => _skip(context),
              child: Text(
                'Plus tard',
                style: IOSTheme.body(context).copyWith(
                  color: IOSTheme.secondaryLabel(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _row(BuildContext context,
      {required IconData icon,
      required String title,
      required String desc}) {
    final blue = IOSTheme.systemBlue(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: blue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: blue, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: IOSTheme.body(context)
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(desc, style: IOSTheme.footnote(context)),
            ],
          ),
        ),
      ],
    );
  }
}
