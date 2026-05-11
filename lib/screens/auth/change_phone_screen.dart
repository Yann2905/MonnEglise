/*
 * FICHIER : lib/screens/auth/change_phone_screen.dart
 *
 * Écran de modification du numéro — 2 étapes :
 * 1. Saisie du nouveau numéro → OTP envoyé via Supabase Auth.updateUser
 * 2. Vérification OTP → mise à jour users.phone
 *
 * Pendant l'étape 2, l'ancien numéro reste actif (Supabase ne le change
 * que quand l'OTP est vérifié).
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/cupertino_theme.dart';
import '../../core/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ios_phone_field.dart';

class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  int _step = 1;
  final _phoneCtrl = TextEditingController();
  String _completePhone = '';
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isValidE164(String phone) =>
      RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(phone);

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
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

  Future<void> _sendOtp() async {
    if (!_isValidE164(_completePhone)) {
      return _alert('Numéro invalide', 'Format requis : +225XXXXXXXXXX');
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (_completePhone == auth.currentUser?.phone) {
      return _alert('Numéro identique', "C'est déjà votre numéro actuel.");
    }
    final ok = await auth.requestPhoneChange(_completePhone);
    if (!mounted) return;
    if (ok) {
      setState(() => _step = 2);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _otpFocusNodes[0].requestFocus();
      });
    } else {
      _alert(
          'Erreur', auth.errorMessage ?? "Impossible d'envoyer le code");
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpControllers.map((c) => c.text).join();
    final err = Validators.validateOtp(code);
    if (err != null) return _alert('Code invalide', err);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.confirmPhoneChange(code);
    if (!mounted) return;
    if (ok) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Numéro mis à jour'),
          content: const Text('Votre nouveau numéro est maintenant actif.'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      _alert('Code incorrect',
          auth.errorMessage ?? 'Le code est invalide ou expiré.');
    }
  }

  void _onOtpChanged(int i, String val) {
    if (val.isNotEmpty && i < 5) _otpFocusNodes[i + 1].requestFocus();
    if (val.isEmpty && i > 0) _otpFocusNodes[i - 1].requestFocus();
    if (i == 5 && val.isNotEmpty) FocusScope.of(context).unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Modifier mon numéro',
            style: TextStyle(
              inherit: false,
              fontFamily: IOSTheme.fontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: IOSTheme.label(context),
            )),
        backgroundColor:
            IOSTheme.groupedBackground(context).withValues(alpha: 0.9),
      ),
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Consumer<AuthProvider>(
            builder: (_, auth, __) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _step == 1
                        ? _buildStep1(auth)
                        : _buildStep2(auth),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── ÉTAPE 1 ──
  Widget _buildStep1(AuthProvider auth) {
    final blue = IOSTheme.systemBlue(context);
    final isDark = IOSTheme.isDark(context);
    final current = auth.currentUser?.phone ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(CupertinoIcons.phone_fill,
                size: 36, color: blue),
          ),
        ),
        const SizedBox(height: 20),
        Text('Nouveau numéro',
            style: IOSTheme.title2(context),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          'Vous recevrez un code à 6 chiffres pour confirmer le changement.',
          style: IOSTheme.subhead(context),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),

        // Numéro actuel (read-only)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: IOSTheme.cardBackground(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(CupertinoIcons.phone,
                  size: 18, color: IOSTheme.tertiaryLabel(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Numéro actuel',
                        style: IOSTheme.caption(context)),
                    const SizedBox(height: 2),
                    Text(current.isEmpty ? '—' : current,
                        style: IOSTheme.body(context)
                            .copyWith(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('NOUVEAU NUMÉRO',
              style: IOSTheme.sectionHeader(context)
                  .copyWith(fontSize: 12, letterSpacing: 0.6)),
        ),
        IOSPhoneField(
          controller: _phoneCtrl,
          onCompletePhoneChanged: (v) => _completePhone = v,
          onSubmitted: _sendOtp,
        ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: blue,
            disabledColor: blue.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(vertical: 17),
            onPressed: auth.isLoading ? null : _sendOtp,
            child: auth.isLoading
                ? const CupertinoActivityIndicator(
                    color: CupertinoColors.white)
                : const Text(
                    'Recevoir le code',
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
      ],
    );
  }

  // ── ÉTAPE 2 ──
  Widget _buildStep2(AuthProvider auth) {
    final blue = IOSTheme.systemBlue(context);
    final isDark = IOSTheme.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(CupertinoIcons.chat_bubble_text_fill,
                size: 36, color: blue),
          ),
        ),
        const SizedBox(height: 20),
        Text('Vérification',
            style: IOSTheme.title2(context),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Code envoyé au $_completePhone',
            style: IOSTheme.subhead(context),
            textAlign: TextAlign.center),
        const SizedBox(height: 28),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _otpBox(i)),
        ),

        const SizedBox(height: 16),

        Center(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: auth.isLoading ? null : _sendOtp,
            child: Text(
              'Renvoyer le code',
              style: TextStyle(
                inherit: false,
                fontFamily: IOSTheme.fontFamily,
                fontSize: 15,
                color: blue,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: blue,
            disabledColor: blue.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(vertical: 17),
            onPressed: auth.isLoading ? null : _verifyOtp,
            child: auth.isLoading
                ? const CupertinoActivityIndicator(
                    color: CupertinoColors.white)
                : const Text(
                    'Vérifier',
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

        const SizedBox(height: 12),

        Center(
          child: CupertinoButton(
            onPressed:
                auth.isLoading ? null : () => setState(() => _step = 1),
            child: Text(
              'Modifier le numéro',
              style: TextStyle(
                inherit: false,
                fontFamily: IOSTheme.fontFamily,
                fontSize: 14,
                color: IOSTheme.secondaryLabel(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _otpBox(int i) {
    final filled = _otpControllers[i].text.isNotEmpty;
    final blue = IOSTheme.systemBlue(context);
    return Container(
      width: 48,
      height: 58,
      decoration: BoxDecoration(
        color: IOSTheme.tertiaryBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              filled ? blue.withValues(alpha: 0.6) : CupertinoColors.transparent,
          width: 1.5,
        ),
      ),
      child: CupertinoTextField(
        controller: _otpControllers[i],
        focusNode: _otpFocusNodes[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        decoration: const BoxDecoration(),
        padding: EdgeInsets.zero,
        style: TextStyle(
          inherit: false,
          fontFamily: IOSTheme.fontFamily,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: filled ? blue : IOSTheme.label(context),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (val) => _onOtpChanged(i, val),
      ),
    );
  }
}
