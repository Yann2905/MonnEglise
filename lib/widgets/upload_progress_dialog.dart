/*
 * FICHIER : lib/widgets/upload_progress_dialog.dart
 *
 * Modal de progression d'upload audio Cloudinary.
 *  • Barre de progression linéaire iOS-style
 *  • Pourcentage en gros + taille uploadée / totale
 *  • Bouton Annuler qui déclenche un CancelToken
 *  • Auto-close à 100% (mais doit être fermé manuellement par le caller)
 *
 * Usage :
 *   final controller = UploadProgressController();
 *   showCupertinoDialog(
 *     context: context,
 *     barrierDismissible: false,
 *     builder: (_) => UploadProgressDialog(
 *       fileName: 'predication.mp3',
 *       controller: controller,
 *       onCancel: () => cancelToken.cancel(),
 *     ),
 *   );
 *   // Au fil de l'upload :
 *   controller.update(sent, total);
 *   // À la fin :
 *   Navigator.pop(context);
 */

import 'package:flutter/cupertino.dart';
import '../core/cupertino_theme.dart';

/// Permet de mettre à jour la progression depuis l'extérieur du widget.
class UploadProgressController extends ChangeNotifier {
  int sent = 0;
  int total = 0;
  String phase = 'Téléchargement…';

  void update(int s, int t) {
    sent = s;
    total = t;
    notifyListeners();
  }

  void setPhase(String p) {
    phase = p;
    notifyListeners();
  }
}

class UploadProgressDialog extends StatefulWidget {
  final String fileName;
  final UploadProgressController controller;
  final VoidCallback? onCancel;

  const UploadProgressDialog({
    super.key,
    required this.fileName,
    required this.controller,
    this.onCancel,
  });

  @override
  State<UploadProgressDialog> createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<UploadProgressDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  String _fmtMo(int bytes) {
    final mo = bytes / (1024 * 1024);
    return '${mo.toStringAsFixed(1)} Mo';
  }

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    final progress = widget.controller.total > 0
        ? widget.controller.sent / widget.controller.total
        : 0.0;
    final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);

    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        decoration: BoxDecoration(
          color: IOSTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(20),
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
            // Icône cloud animée
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                final scale = 1.0 + 0.08 * _pulseCtrl.value;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: blue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CupertinoIcons.cloud_upload_fill,
                        color: blue, size: 36),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Nom du fichier
            Text(
              widget.fileName,
              style: IOSTheme.body(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Phase (Téléchargement / Finalisation)
            Text(
              widget.controller.phase,
              style: IOSTheme.footnote(context),
            ),
            const SizedBox(height: 20),

            // Pourcentage en gros (Cormorant pour le style)
            Text(
              '$percent %',
              style: TextStyle(
                inherit: false,
                fontFamily: IOSTheme.fontFamily,
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: blue,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 6),

            // Taille uploadée / totale
            if (widget.controller.total > 0)
              Text(
                '${_fmtMo(widget.controller.sent)} / ${_fmtMo(widget.controller.total)}',
                style: IOSTheme.caption(context),
              ),
            const SizedBox(height: 18),

            // Barre de progression linéaire
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(
                      color: IOSTheme.tertiaryBackground(context),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [blue, blue.withValues(alpha: 0.7)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Bouton Annuler
            if (widget.onCancel != null)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: widget.onCancel,
                child: Text(
                  'Annuler',
                  style: TextStyle(
                    inherit: false,
                    fontFamily: IOSTheme.fontFamily,
                    fontSize: 15,
                    color: IOSTheme.systemRed(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
