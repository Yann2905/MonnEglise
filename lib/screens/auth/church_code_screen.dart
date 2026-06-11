/*
 * FICHIER : lib/screens/auth/church_code_screen.dart
 *
 * Écran dédié — premier pas du flow d'inscription membre.
 *  • Demande le code d'invitation de l'église
 *  • Valide via AuthService.resolveJoinCode
 *  • Si OK → navigation vers RegisterMemberScreen avec le code + adminId
 *
 * Pourquoi un écran dédié ?
 *  - Identifier l'église en amont permet de charger ses familles
 *  - Plus rapide pour l'utilisateur : un seul champ, validation immédiate
 *  - Code invalide → message clair, pas de formulaire perdu à re-remplir
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/cupertino_theme.dart';
import '../../services/auth_service.dart';
import 'register_member_screen.dart';

class ChurchCodeScreen extends StatefulWidget {
  const ChurchCodeScreen({super.key});

  @override
  State<ChurchCodeScreen> createState() => _ChurchCodeScreenState();
}

class _ChurchCodeScreenState extends State<ChurchCodeScreen> {
  final _codeCtrl = TextEditingController();
  final _authService = AuthService();
  bool _isValidating = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _alert(String title, String desc) {
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

  Future<void> _validate() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 4 || code.length > 8) {
      return _alert('Code invalide',
          "Le code doit contenir entre 4 et 8 caractères.");
    }
    setState(() => _isValidating = true);
    try {
      final adminId = await _authService.resolveJoinCode(code);
      if (!mounted) return;
      if (adminId == null) {
        _alert('Code invalide',
            "Ce code n'existe pas. Demande à ton pasteur le code de votre église.");
        return;
      }

      // Récupère le church_id réel de l'admin (pour charger les familles)
      final supa = Supabase.instance.client;
      final adminRow = await supa
          .from('users')
          .select('church_id')
          .eq('id', adminId)
          .maybeSingle();
      final churchId = adminRow?['church_id'] as String?;
      if (churchId == null || churchId.isEmpty) {
        _alert('Erreur', "L'église associée à ce code est introuvable.");
        return;
      }

      if (!mounted) return;
      // Code OK → on enchaîne sur l'inscription en passant les infos
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(
          builder: (_) => RegisterMemberScreen(
            preValidatedCode: code,
            preValidatedAdminId: adminId,
            preValidatedChurchId: churchId,
          ),
        ),
      );
    } catch (_) {
      if (mounted) _alert('Erreur', 'Impossible de vérifier le code.');
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    // Back arrow
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.maybePop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.centerLeft,
                          child: Icon(
                            CupertinoIcons.chevron_left,
                            color: IOSTheme.label(context),
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Illustration / icône
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: blue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.building_2_fill,
                          color: blue,
                          size: 42,
                        ),
                      ),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.7, 0.7),
                          end: const Offset(1, 1),
                          duration: 400.ms,
                          curve: Curves.easeOutBack,
                        )
                        .fadeIn(duration: 350.ms),
                    const SizedBox(height: 28),

                    // Titre
                    Text(
                      "Rejoindre une église",
                      style: IOSTheme.largeTitle(context),
                      textAlign: TextAlign.center,
                    )
                        .animate(delay: 100.ms)
                        .fadeIn(duration: 350.ms)
                        .slideY(
                            begin: 0.15,
                            end: 0,
                            duration: 400.ms,
                            curve: Curves.easeOutCubic),
                    const SizedBox(height: 10),

                    // Sous-titre
                    Text(
                      "Saisis le code d'invitation que ton pasteur t'a transmis.",
                      style: IOSTheme.body(context).copyWith(
                        color: IOSTheme.secondaryLabel(context),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ).animate(delay: 180.ms).fadeIn(duration: 350.ms),
                    const SizedBox(height: 32),

                    // Champ code
                    Container(
                      height: 68,
                      decoration: BoxDecoration(
                        color: IOSTheme.tertiaryBackground(context),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: CupertinoTextField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.text,
                        maxLength: 8,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const BoxDecoration(),
                        padding: EdgeInsets.zero,
                        placeholder: 'EBAC25',
                        placeholderStyle: TextStyle(
                          inherit: false,
                          fontFamily: IOSTheme.fontFamily,
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          color: IOSTheme.tertiaryLabel(context),
                          letterSpacing: 8,
                        ),
                        style: TextStyle(
                          inherit: false,
                          fontFamily: IOSTheme.fontFamily,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: IOSTheme.label(context),
                          letterSpacing: 8,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]')),
                          _UpperCaseFormatter(),
                        ],
                        onSubmitted: (_) => _validate(),
                      ),
                    ).animate(delay: 260.ms).fadeIn(duration: 350.ms),

                    const SizedBox(height: 24),

                    // Bouton valider
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: blue,
                        disabledColor: blue.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        onPressed: _isValidating ? null : _validate,
                        child: _isValidating
                            ? const CupertinoActivityIndicator(
                                color: CupertinoColors.white)
                            : Text(
                                'Valider',
                                style: TextStyle(
                                  inherit: false,
                                  fontFamily: IOSTheme.fontFamily,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.white,
                                ),
                              ),
                      ),
                    ).animate(delay: 320.ms).fadeIn(duration: 350.ms),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Force le texte en majuscules en temps réel
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
