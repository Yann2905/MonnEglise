/*
 * FICHIER : lib/widgets/exit_on_back_scope.dart
 *
 * Widget qui intercepte le bouton retour Android sur les écrans-racines
 * (dashboards) et affiche un dialog de confirmation "Quitter l'application ?"
 * au lieu de simplement pop la route (qui renverrait au splash/login).
 *
 * Usage :
 *   ExitOnBackScope(child: <CupertinoPageScaffold ...>)
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show SystemNavigator;

class ExitOnBackScope extends StatelessWidget {
  final Widget child;
  const ExitOnBackScope({super.key, required this.child});

  Future<bool> _confirmExit(BuildContext context) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Quitter l'application ?"),
        content: const Text('Vous resterez connecté à votre compte.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _confirmExit(context);
        if (shouldExit) {
          // Ferme proprement l'app (Android) ; sur iOS, ignoré par le système.
          await SystemNavigator.pop();
        }
      },
      child: child,
    );
  }
}
