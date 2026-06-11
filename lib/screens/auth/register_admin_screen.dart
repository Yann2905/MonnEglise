/*
 * FICHIER : lib/screens/auth/register_admin_screen.dart
 *
 * REDESIGN "iOS" — Inscription Administrateur :
 * — CupertinoNavigationBar + back natif
 * — Banner info bleu translucide
 * — Champs iOS arrondis (CupertinoTextField)
 * — IOSPhoneField partagé pour le téléphone
 * — Bouton bleu plein
 * — OTP via modal Cupertino plein écran (drag handle)
 * — Alerts CupertinoAlertDialog natifs
 */

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_providers;
import '../../core/cupertino_theme.dart';
import '../../core/validators.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/church_setup_modal.dart';
import '../../widgets/ios_date_picker_field.dart';
import '../../widgets/ios_phone_field.dart';

class RegisterAdminScreen extends StatefulWidget {
  const RegisterAdminScreen({super.key});

  @override
  State<RegisterAdminScreen> createState() => _RegisterAdminScreenState();
}

class _RegisterAdminScreenState extends State<RegisterAdminScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _quartierController = TextEditingController();

  String _completePhoneNumber = '';
  DateTime? _birthDate;
  XFile? _avatarFile;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _quartierController.dispose();
    super.dispose();
  }

  bool _isValidE164(String phone) =>
      RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(phone);

  // ══════════════════════════════════════════════
  //  ACTIONS
  // ══════════════════════════════════════════════

  Future<void> _handleRegister() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final quartier = _quartierController.text.trim();

    final fnErr = Validators.validateName(firstName, 'Le prénom');
    if (fnErr != null) return _showAlert('Champ invalide', fnErr);
    final lnErr = Validators.validateName(lastName, 'Le nom');
    if (lnErr != null) return _showAlert('Champ invalide', lnErr);
    final qErr = Validators.validateQuartier(quartier);
    if (qErr != null) return _showAlert('Champ invalide', qErr);

    if (!_isValidE164(_completePhoneNumber)) {
      return _showAlert(
        'Numéro invalide',
        'Format requis : +225XXXXXXXXXX',
      );
    }

    final auth = Provider.of<app_providers.AuthProvider>(context, listen: false);
    final data = {
      'firstName': firstName,
      'lastName': lastName,
      'phone': _completePhoneNumber,
      'quartier': quartier,
      if (_birthDate != null)
        'birthDate':
            '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
    };

    // L'avatar est passé hors du map (XFile non sérialisable en String)
    auth.setPendingAvatar(_avatarFile);

    try {
      // Mode sans OTP : inscription directe
      final memberCode = await auth.registerAdminDirect(data: data);
      if (!mounted) return;

      if (memberCode != null) {
        _showSuccessDialog(memberCode);
      } else {
        _showAlert('Erreur',
            auth.errorMessage ?? 'Impossible de créer le compte');
      }
    } catch (e) {
      if (!mounted) return;
      _showAlert('Erreur', 'Une erreur est survenue : $e');
    }
  }

  void _showOtpSheet(Map<String, String> data) {
    final otpControllers = List.generate(6, (_) => TextEditingController());
    final otpFocusNodes = List.generate(6, (_) => FocusNode());

    showCupertinoModalPopup(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool verifying = false;

        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final blue = IOSTheme.systemBlue(ctx);

            void onChanged(int i, String val) {
              if (val.isNotEmpty && i < 5) otpFocusNodes[i + 1].requestFocus();
              if (val.isEmpty && i > 0) otpFocusNodes[i - 1].requestFocus();
              if (i == 5 && val.isNotEmpty) FocusScope.of(ctx).unfocus();
              setSheet(() {});
            }

            Future<void> verify() async {
              final code = otpControllers.map((c) => c.text).join();
              if (code.length != 6) return;
              setSheet(() => verifying = true);

              final auth = Provider.of<app_providers.AuthProvider>(
                  context, listen: false);
              final memberCode =
                  await auth.finalizeAdminRegistration(code, data);

              if (!mounted) return;
              setSheet(() => verifying = false);

              if (memberCode != null) {
                Navigator.pop(ctx);
                _showSuccessDialog(memberCode);
              } else {
                _showAlert('Code invalide',
                    auth.errorMessage ?? 'Code OTP incorrect ou expiré');
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: IOSTheme.cardBackground(ctx),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: EdgeInsets.only(
                top: 8,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: IOSTheme.tertiaryLabel(ctx),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: blue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(CupertinoIcons.chat_bubble_text_fill,
                        color: blue, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text('Vérification', style: IOSTheme.title2(ctx)),
                  const SizedBox(height: 4),
                  Text(
                    'Code envoyé au ${data['phone']}',
                    style: IOSTheme.subhead(ctx),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) => _otpBox(
                          ctx,
                          otpControllers[i],
                          otpFocusNodes[i],
                          (val) => onChanged(i, val),
                        )),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          color: IOSTheme.tertiaryBackground(ctx),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          borderRadius: BorderRadius.circular(12),
                          onPressed:
                              verifying ? null : () => Navigator.pop(ctx),
                          child: Text(
                            'Annuler',
                            style: TextStyle(
                              inherit: false,
                              fontFamily: IOSTheme.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: IOSTheme.label(ctx),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton(
                          color: blue,
                          disabledColor: blue.withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: verifying ? null : verify,
                          child: verifying
                              ? const CupertinoActivityIndicator(
                                  color: CupertinoColors.white)
                              : const Text(
                                  'Vérifier',
                                  style: TextStyle(
                                    inherit: false,
                                    fontFamily: IOSTheme.fontFamily,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _otpBox(BuildContext ctx, TextEditingController c, FocusNode f,
      ValueChanged<String> onChanged) {
    final filled = c.text.isNotEmpty;
    final blue = IOSTheme.systemBlue(ctx);
    return Container(
      width: 44,
      height: 56,
      decoration: BoxDecoration(
        color: IOSTheme.tertiaryBackground(ctx),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              filled ? blue.withValues(alpha: 0.6) : CupertinoColors.transparent,
          width: 1.5,
        ),
      ),
      child: CupertinoTextField(
        controller: c,
        focusNode: f,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        decoration: const BoxDecoration(),
        padding: EdgeInsets.zero,
        style: TextStyle(
          inherit: false,
          fontFamily: IOSTheme.fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: filled ? blue : IOSTheme.label(ctx),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
      ),
    );
  }

  void _showSuccessDialog(String memberCode) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Inscription réussie'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Votre code membre est :'),
              const SizedBox(height: 12),
              Text(
                memberCode,
                style: TextStyle(
                  inherit: false,
                  fontFamily: IOSTheme.fontFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: IOSTheme.systemBlue(ctx),
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Notez-le précieusement.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final navContext = context;
              Navigator.pop(ctx);
              if (mounted) _showChurchSetupModal(navContext);
            },
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  void _showChurchSetupModal(BuildContext ctx) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => ChurchSetupModal(
        onComplete: () =>
            Navigator.pushReplacementNamed(ctx, '/admin-welcome'),
      ),
    );
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

    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Consumer<app_providers.AuthProvider>(
                builder: (_, auth, __) {
                  return SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),

                        // Back arrow
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.canPop(context)
                                ? Navigator.pop(context)
                                : Navigator.pushReplacementNamed(
                                    context, '/'),
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

                        const SizedBox(height: 16),

                        // Titre Cormorant
                        Text(
                          'Inscription\nadministrateur',
                          style: IOSTheme.largeTitle(context),
                        )
                            .animate()
                            .fadeIn(duration: 350.ms)
                            .slideY(
                                begin: 0.15,
                                end: 0,
                                duration: 400.ms,
                                curve: Curves.easeOutCubic),

                        const SizedBox(height: 8),

                        Text(
                          "Crée et gère ton église, tes membres et tes familles.",
                          style: IOSTheme.body(context).copyWith(
                            color: IOSTheme.secondaryLabel(context),
                            height: 1.4,
                          ),
                        )
                            .animate(delay: 80.ms)
                            .fadeIn(duration: 350.ms),

                        const SizedBox(height: 28),

                        // ── Avatar picker ──
                        Center(
                          child: AvatarPicker(
                            file: _avatarFile,
                            size: 96,
                            onPicked: (f) =>
                                setState(() => _avatarFile = f),
                          ),
                        )
                            .animate(delay: 140.ms)
                            .fadeIn(duration: 350.ms)
                            .scale(
                                begin: const Offset(0.85, 0.85),
                                end: const Offset(1, 1),
                                duration: 350.ms,
                                curve: Curves.easeOutBack),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            _avatarFile != null
                                ? 'Toucher pour changer'
                                : 'Ajouter une photo (facultatif)',
                            style: IOSTheme.caption(context),
                          ),
                        ),

                        const SizedBox(height: 24),

                        _sectionHeader(context, 'IDENTITÉ'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _iosField(
                                controller: _firstNameController,
                                placeholder: 'Prénom',
                                icon: CupertinoIcons.person,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _iosField(
                                controller: _lastNameController,
                                placeholder: 'Nom',
                                icon: CupertinoIcons.person_fill,
                              ),
                            ),
                          ],
                        )
                            .animate(delay: 80.ms)
                            .fadeIn(duration: 300.ms)
                            .slideY(
                                begin: 0.1,
                                end: 0,
                                duration: 300.ms,
                                curve: Curves.easeOutCubic),

                        const SizedBox(height: 20),

                        _sectionHeader(context, 'TÉLÉPHONE'),
                        const SizedBox(height: 8),
                        IOSPhoneField(
                          controller: _phoneController,
                          onCompletePhoneChanged: (v) =>
                              _completePhoneNumber = v,
                        )
                            .animate(delay: 140.ms)
                            .fadeIn(duration: 300.ms)
                            .slideY(
                                begin: 0.1,
                                end: 0,
                                duration: 300.ms,
                                curve: Curves.easeOutCubic),

                        const SizedBox(height: 20),

                        _sectionHeader(context, 'QUARTIER'),
                        const SizedBox(height: 8),
                        _iosField(
                          controller: _quartierController,
                          placeholder: 'Votre quartier de résidence',
                          icon: CupertinoIcons.location,
                        )
                            .animate(delay: 200.ms)
                            .fadeIn(duration: 300.ms)
                            .slideY(
                                begin: 0.1,
                                end: 0,
                                duration: 300.ms,
                                curve: Curves.easeOutCubic),

                        const SizedBox(height: 20),

                        _sectionHeader(context, 'DATE DE NAISSANCE'),
                        const SizedBox(height: 8),
                        IOSDatePickerField(
                          value: _birthDate,
                          placeholder: 'Sélectionner votre date de naissance',
                          onChanged: (d) => setState(() => _birthDate = d),
                        )
                            .animate(delay: 230.ms)
                            .fadeIn(duration: 300.ms)
                            .slideY(
                                begin: 0.1,
                                end: 0,
                                duration: 300.ms,
                                curve: Curves.easeOutCubic),

                        const SizedBox(height: 32),

                        _primaryButton(
                          label: "S'inscrire",
                          isLoading: auth.isLoading,
                          onTap: auth.isLoading ? null : _handleRegister,
                        )
                            .animate(delay: 260.ms)
                            .fadeIn(duration: 300.ms)
                            .slideY(
                                begin: 0.1,
                                end: 0,
                                duration: 300.ms,
                                curve: Curves.easeOutCubic),

                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers UI ──

  Widget _sectionHeader(BuildContext ctx, String text) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: IOSTheme.sectionHeader(ctx).copyWith(
            fontSize: 12,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _iosField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: IOSTheme.tertiaryBackground(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        decoration: const BoxDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(icon,
              size: 18, color: IOSTheme.tertiaryLabel(context)),
        ),
        style: IOSTheme.body(context),
        placeholderStyle: IOSTheme.body(context).copyWith(
          color: IOSTheme.placeholder(context),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    final blue = IOSTheme.systemBlue(context);
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        color: blue,
        disabledColor: blue.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(vertical: 17),
        onPressed: onTap,
        child: isLoading
            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
            : Text(
                label,
                style: const TextStyle(
                  inherit: false,
                  fontFamily: IOSTheme.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                  letterSpacing: -0.41,
                ),
              ),
      ),
    );
  }
}
