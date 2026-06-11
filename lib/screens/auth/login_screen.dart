/*
 * FICHIER : lib/screens/auth/login_screen.dart
 *
 * REDESIGN "iOS" — Style Cupertino natif :
 * — CupertinoPageScaffold + barre translucide
 * — CupertinoTextField (rounded gris clair, prefix icon SF)
 * — CupertinoButton.filled (bouton bleu plein iOS)
 * — CupertinoAlertDialog (alerts natifs iOS)
 * — Indicateur d'étape avec pastilles iOS systemBlue
 * — OTP : 6 cellules iOS-rounded, focus animé subtilement
 * — Animations conservées (fade/slide) mais réduites pour rester iOS-like
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/validators.dart';
import '../../core/cupertino_theme.dart';
import '../../widgets/ios_phone_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {

  // ── Contrôleurs ──
  final _phoneController = TextEditingController();
  final _otpControllers  = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes   = List.generate(6, (_) => FocusNode());
  final _phoneFocus      = FocusNode();

  /// Numéro complet avec préfixe pays (ex: +2250712345678)
  /// Mis à jour par IOSPhoneField via onCompletePhoneChanged.
  String _completePhoneNumber = '';

  int _currentStep = 1;

  // ── Animations ──
  late AnimationController _slideCtrl;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _fadeAnim;

  final List<bool> _otpFilled = List.generate(6, (_) => false);

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.12, 0),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut),
    );

    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) { c.dispose(); }
    for (final f in _otpFocusNodes)  { f.dispose(); }
    _phoneFocus.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════
  //  ACTIONS
  // ══════════════════════════════════════════════

  /// Mode sans OTP : connexion directe par numéro de téléphone.
  Future<void> _handleSendOTP() async {
    final phone = _completePhoneNumber.trim();
    final err = Validators.validatePhone(phone);
    if (err != null) {
      _showAlert('Numéro invalide', err);
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.loginByPhone(phone);
    if (!mounted) return;

    if (ok) {
      _showSuccessAndNavigate(auth);
    } else {
      _showAlert(
          'Numéro non reconnu',
          auth.errorMessage ??
              "Ce numéro n'est pas inscrit. Crée un compte d'abord.");
    }
  }

  Future<void> _handleVerifyOTP() async {
    final code = _otpControllers.map((c) => c.text).join();
    final err  = Validators.validateOtp(code);
    if (err != null) {
      _showAlert('Code invalide', err);
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok   = await auth.verifyOTP(code);
    if (!mounted) return;

    if (ok) {
      _showSuccessAndNavigate(auth);
    } else {
      _showAlert('Code invalide', auth.errorMessage ?? 'Code incorrect ou expiré');
    }
  }

  Future<void> _animateToStep(int step) async {
    await _slideCtrl.reverse();
    if (!mounted) return;
    setState(() {
      _currentStep = step;
      for (final c in _otpControllers) { c.clear(); }
      for (int i = 0; i < 6; i++) { _otpFilled[i] = false; }
    });
    await _slideCtrl.forward();
    if (step == 2 && mounted) {
      Future.delayed(150.ms, () {
        if (mounted) _otpFocusNodes[0].requestFocus();
      });
    }
  }

  Future<void> _goBackToStep1() async {
    await _animateToStep(1);
    if (mounted) {
      Future.delayed(150.ms, () {
        if (mounted) _phoneFocus.requestFocus();
      });
    }
  }

  void _showSuccessAndNavigate(AuthProvider auth) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Connexion réussie'),
        content: Text('Bienvenue ${auth.currentUser?.firstName ?? ''} !'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(
                context,
                auth.isAdmin ? '/admin-dashboard' : '/member-dashboard',
                (_) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
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

  void _onOtpChanged(int index, String val) {
    setState(() => _otpFilled[index] = val.isNotEmpty);
    if (val.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (val.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    if (index == 5 && val.isNotEmpty) {
      FocusScope.of(context).unfocus();
    }
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
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),

                        // ── Back arrow ──
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => Navigator.canPop(context)
                                ? Navigator.pop(context)
                                : Navigator.pushReplacementNamed(context, '/'),
                            behavior: HitTestBehavior.opaque,
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

                        const SizedBox(height: 24),

                        // ── Titre Cormorant ──
                        Text(
                          'Bienvenue',
                          style: IOSTheme.largeTitle(context),
                        )
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.15, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),

                        const SizedBox(height: 8),

                        // ── Sous-titre ──
                        Text(
                          'Entrez votre numéro de téléphone pour vous connecter.',
                          style: IOSTheme.body(context).copyWith(
                            color: IOSTheme.secondaryLabel(context),
                            height: 1.4,
                          ),
                        )
                        .animate(delay: 100.ms)
                        .fadeIn(duration: 350.ms),

                        const SizedBox(height: 36),

                        _buildPhoneStep(auth, blue)
                          .animate(delay: 200.ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.10, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),

                        const SizedBox(height: 28),

                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Pas encore inscrit ? ",
                                style: IOSTheme.footnote(context),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                onPressed: () => Navigator.pushNamed(context, '/register-choice'),
                                child: Text(
                                  "S'inscrire",
                                  style: TextStyle(
                                    inherit: false,
                                    fontFamily: IOSTheme.fontFamily,
                                    fontSize:   13,
                                    fontWeight: FontWeight.w700,
                                    color:      blue,
                                    letterSpacing: -0.08,
                                  ),
                                ),
                              ),
                            ],
                          )
                          .animate(delay: 320.ms)
                          .fadeIn(duration: 300.ms),

                        const SizedBox(height: 32),
                      ],
                    ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  WIDGETS INTERNES
  // ══════════════════════════════════════════════

  Widget _buildLogo(Color blue) {
    final isDark = IOSTheme.isDark(context);
    return Center(
      child: Container(
        width:  84,
        height: 84,
        decoration: BoxDecoration(
          color: blue.withValues(alpha: isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          CupertinoIcons.building_2_fill,
          size: 40,
          color: blue,
        ),
      ),
    );
  }

  Widget _buildStepIndicator(Color blue) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve:    Curves.easeInOut,
          width:    _currentStep == 1 ? 22 : 6,
          height:   6,
          decoration: BoxDecoration(
            color: _currentStep >= 1 ? blue : blue.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve:    Curves.easeInOut,
          width:    _currentStep == 2 ? 22 : 6,
          height:   6,
          decoration: BoxDecoration(
            color: _currentStep == 2 ? blue : blue.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }

  // ── Étape 1 ──────────────────────────────────
  Widget _buildPhoneStep(AuthProvider auth, Color blue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IOSPhoneField(
          controller: _phoneController,
          focusNode:  _phoneFocus,
          placeholder: '07 XX XX XX XX',
          onCompletePhoneChanged: (v) => _completePhoneNumber = v,
          onSubmitted: _handleSendOTP,
        ),
        const SizedBox(height: 28),
        _buildPrimaryButton(
          label:     'Continuer',
          isLoading: auth.isLoading,
          onTap:     auth.isLoading ? null : _handleSendOTP,
          blue:      blue,
        ),
      ],
    );
  }

  // ── Étape 2 ──────────────────────────────────
  Widget _buildOtpStep(AuthProvider auth, Color blue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            6,
            (i) => _buildOtpBox(i, blue)
              .animate(delay: Duration(milliseconds: 35 * i))
              .scale(
                begin:    const Offset(0.7, 0.7),
                end:      const Offset(1.0, 1.0),
                duration: 250.ms,
                curve:    Curves.easeOutBack,
              )
              .fadeIn(duration: 180.ms),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              onPressed: auth.isLoading ? null : _goBackToStep1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.chevron_left, size: 16, color: blue),
                  const SizedBox(width: 4),
                  Text(
                    'Changer',
                    style: TextStyle(
                      inherit: false,
                      fontFamily: IOSTheme.fontFamily,
                      fontSize: 15,
                      color: blue,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              onPressed: auth.isLoading ? null : _handleSendOTP,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.arrow_clockwise, size: 16, color: blue),
                  const SizedBox(width: 4),
                  Text(
                    'Renvoyer',
                    style: TextStyle(
                      inherit: false,
                      fontFamily: IOSTheme.fontFamily,
                      fontSize: 15,
                      color: blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildPrimaryButton(
          label:     'Se connecter',
          isLoading: auth.isLoading,
          onTap:     auth.isLoading ? null : _handleVerifyOTP,
          blue:      blue,
        ),
      ],
    );
  }

  Widget _buildOtpBox(int index, Color blue) {
    final isFilled = _otpFilled[index];
    final isFocused = _otpFocusNodes[index].hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve:    Curves.easeOut,
      width:    48,
      height:   54,
      decoration: BoxDecoration(
        color: isFilled
            ? blue.withValues(alpha: 0.08)
            : IOSTheme.tertiaryBackground(context),
        borderRadius: BorderRadius.circular(27), // quasi-circulaire
        border: Border.all(
          color: isFilled
              ? blue
              : (isFocused
                  ? blue.withValues(alpha: 0.5)
                  : IOSTheme.separator(context)),
          width: isFilled ? 2 : 1.2,
        ),
      ),
      child: CupertinoTextField(
        controller:   _otpControllers[index],
        focusNode:    _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign:    TextAlign.center,
        maxLength:    1,
        decoration:   const BoxDecoration(),
        padding:      EdgeInsets.zero,
        style: TextStyle(
          inherit: false,
          fontFamily: IOSTheme.fontFamily,
          fontSize:   22,
          fontWeight: FontWeight.w700,
          color:      isFilled ? blue : IOSTheme.label(context),
          letterSpacing: 0,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (val) => _onOtpChanged(index, val),
      ),
    );
  }

  // ── Bouton principal iOS ─────────────────────
  Widget _buildPrimaryButton({
    required String        label,
    required bool          isLoading,
    required VoidCallback? onTap,
    required Color         blue,
  }) {
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
                  fontSize:   17,
                  fontWeight: FontWeight.w600,
                  color:      CupertinoColors.white,
                  letterSpacing: -0.41,
                ),
              ),
      ),
    );
  }

}
