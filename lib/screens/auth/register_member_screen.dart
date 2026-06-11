/*
 * FICHIER : lib/screens/auth/register_member_screen.dart
 *
 * REDESIGN "iOS" — Inscription Membre (3 étapes) :
 * — Étape 1 : code à 6 chiffres (validation côté serveur)
 * — Étape 2 : formulaire complet (nom, téléphone, quartier, rôle, familles)
 * — Étape 3 : vérification OTP en 6 cellules
 * Tout en Cupertino : navigation bar, alerts, sheets, indicateurs.
 */

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../core/cupertino_theme.dart';
import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/ios_date_picker_field.dart';
import '../../widgets/ios_phone_field.dart';

class RegisterMemberScreen extends StatefulWidget {
  /// Code d'invitation pré-validé (depuis ChurchCodeScreen).
  /// Si fourni, l'écran skippe directement à l'étape formulaire.
  final String? preValidatedCode;

  /// ID de l'admin résolu depuis le code.
  final String? preValidatedAdminId;

  /// ID de l'église résolue depuis le code (utilisé pour charger les familles).
  final String? preValidatedChurchId;

  const RegisterMemberScreen({
    super.key,
    this.preValidatedCode,
    this.preValidatedAdminId,
    this.preValidatedChurchId,
  });

  @override
  State<RegisterMemberScreen> createState() => _RegisterMemberScreenState();
}

class _RegisterMemberScreenState extends State<RegisterMemberScreen> {
  // Étape : 1 = code, 2 = formulaire, 3 = OTP
  late int _currentStep;

  final _authService = AuthService();
  final _dbService = DatabaseService();

  // ── Étape 1 ──
  final _memberCodeController = TextEditingController();
  bool _isValidatingCode = false;

  // ── Étape 2 ──
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _quartierController = TextEditingController();
  String _completePhoneNumber = '';
  String? _selectedRole;
  String? _selectedGender; // 'homme' | 'femme'
  List<String> _selectedFamilyIds = [];
  List<Map<String, dynamic>> _availableFamilies = [];
  DateTime? _birthDate;
  XFile? _avatarFile;
  // ignore: unused_field — gardé pour usage futur (mémorise l'admin lié au code)
  String? _validatedAdminId;

  // ── Étape 3 ──
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  Map<String, String>? _pendingData;

  @override
  void initState() {
    super.initState();
    if (widget.preValidatedCode != null && widget.preValidatedAdminId != null) {
      _currentStep = 2;
      _memberCodeController.text = widget.preValidatedCode!;
      _validatedAdminId = widget.preValidatedAdminId;
      // Pré-charge les familles via le church_id (créées par le pasteur principal)
      final churchId = widget.preValidatedChurchId;
      if (churchId != null && churchId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadFamilies(churchId);
        });
      }
    } else {
      _currentStep = 1;
    }
  }

  @override
  void dispose() {
    _memberCodeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _quartierController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  bool _isValidE164(String phone) =>
      RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(phone);

  // ══════════════════════════════════════════════
  //  ALERTS
  // ══════════════════════════════════════════════
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

  /// Modal "Félicitations vous êtes le/la responsable de [famille]"
  /// Retourne true si l'utilisateur confirme, false/null s'il annule.
  Future<bool?> _showCongrats(String article, String familyName) {
    final blue = IOSTheme.systemBlue(context);
    return showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Column(
          children: [
            Icon(CupertinoIcons.star_circle_fill, color: blue, size: 44),
            const SizedBox(height: 8),
            const Text('Félicitations !'),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            "Vous êtes $article${familyName.isEmpty ? '' : ' de "$familyName"'}.",
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  ÉTAPE 1 : CODE MEMBRE
  // ══════════════════════════════════════════════
  Future<void> _validateMemberCode() async {
    final code = _memberCodeController.text.trim().toUpperCase();
    if (code.length < 4 || code.length > 8) {
      return _alert('Code invalide',
          "Le code doit contenir 6 caractères (lettres et chiffres).");
    }
    setState(() => _isValidatingCode = true);
    try {
      final adminId = await _authService.resolveJoinCode(code);
      if (!mounted) return;
      if (adminId != null) {
        // On résout le church_id depuis l'admin pour charger les bonnes familles
        final supa = Supabase.instance.client;
        final row = await supa
            .from('users')
            .select('church_id')
            .eq('id', adminId)
            .maybeSingle();
        final churchId = row?['church_id'] as String?;
        if (churchId != null && churchId.isNotEmpty) {
          await _loadFamilies(churchId);
        }
        setState(() {
          _validatedAdminId = adminId;
          _currentStep = 2;
        });
      } else {
        _alert('Code invalide',
            "Ce code n'existe pas. Demande à ton pasteur le code d'invitation de l'église.");
      }
    } catch (_) {
      if (mounted) _alert('Erreur', 'Impossible de vérifier le code.');
    } finally {
      if (mounted) setState(() => _isValidatingCode = false);
    }
  }

  Future<void> _loadFamilies(String adminId) async {
    try {
      final families = await _dbService.getFamilies(adminId);
      if (!mounted) return;
      setState(() {
        _availableFamilies = families
            .map((f) => {'id': f['id'], 'name': f['name']})
            .toList();
      });
    } catch (e) {
      // ignore : on continue sans familles
    }
  }

  // ══════════════════════════════════════════════
  //  ÉTAPE 2 : FORMULAIRE
  // ══════════════════════════════════════════════
  Future<void> _handleSubmitForm() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final quartier = _quartierController.text.trim();

    final fnErr = Validators.validateName(firstName, 'Le prénom');
    if (fnErr != null) return _alert('Champ invalide', fnErr);
    final lnErr = Validators.validateName(lastName, 'Le nom');
    if (lnErr != null) return _alert('Champ invalide', lnErr);
    final qErr = Validators.validateQuartier(quartier);
    if (qErr != null) return _alert('Champ invalide', qErr);

    if (!_isValidE164(_completePhoneNumber)) {
      return _alert(
          'Numéro invalide', 'Format requis : +225XXXXXXXXXX');
    }

    if (_selectedRole == null) {
      return _alert('Rôle requis', 'Veuillez sélectionner votre rôle.');
    }
    // Genre : déduit pour Diacre/Diaconesse, sinon obligatoire
    final implied =
        AppConstants.impliedGenderForRole(_selectedRole!);
    final genderToUse = implied ?? _selectedGender;
    if (genderToUse == null) {
      return _alert(
          'Genre requis', 'Veuillez sélectionner Homme ou Femme.');
    }
    if (_selectedRole == AppConstants.churchRoleResponsableFamille &&
        _selectedFamilyIds.length != 1) {
      return _alert('Famille requise',
          "Un responsable doit être affecté à exactement une famille.");
    }

    // Modal "Félicitations" si responsable
    if (_selectedRole == AppConstants.churchRoleResponsableFamille &&
        _selectedFamilyIds.isNotEmpty) {
      final familyName = _availableFamilies
              .firstWhere((f) => f['id'] == _selectedFamilyIds.first,
                  orElse: () => {'name': ''})['name'] ??
          '';
      final article = genderToUse == AppConstants.genderFemale
          ? 'la responsable'
          : 'le responsable';
      final confirmed = await _showCongrats(article, familyName);
      if (confirmed != true) return; // user a annulé
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    _pendingData = {
      'firstName': firstName,
      'lastName': lastName,
      'phone': _completePhoneNumber,
      'quartier': quartier,
      'role': _selectedRole!,         // (legacy) — toujours stocké
      'churchRole': _selectedRole!,   // nouveau système (snake_case)
      'gender': genderToUse,
      'familyIds': _selectedFamilyIds.join(','),
      if (_birthDate != null)
        'birthDate':
            '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
    };

    // L'avatar est passé hors du map (XFile non sérialisable)
    auth.setPendingAvatar(_avatarFile);

    // Mode sans OTP : inscription directe + auto-login
    final ok = await auth.registerMemberDirect(
      memberCode: _memberCodeController.text.trim().toUpperCase(),
      data: _pendingData!,
    );

    if (!mounted) return;
    if (ok) {
      // Direct vers la page de bienvenue (plus d'OTP)
      Navigator.pushReplacementNamed(context, '/member-welcome');
    } else {
      _alert(
          'Erreur', auth.errorMessage ?? "Inscription impossible.");
    }
  }

  // ══════════════════════════════════════════════
  //  ÉTAPE 3 : OTP
  // ══════════════════════════════════════════════
  Future<void> _handleVerifyOTP() async {
    final code = _otpControllers.map((c) => c.text).join();
    final err = Validators.validateOtp(code);
    if (err != null) return _alert('Code invalide', err);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.finalizeMemberRegistration(
      code,
      _memberCodeController.text.trim().toUpperCase(),
      _pendingData!,
    );

    if (!mounted) return;
    if (ok) {
      // Redirige vers la page de bienvenue (logo + nom église + bouton Entrer)
      Navigator.pushReplacementNamed(context, '/member-welcome');
    } else {
      _alert('Code invalide',
          auth.errorMessage ?? 'Le code est incorrect ou a expiré.');
    }
  }

  void _onOtpChanged(int i, String val) {
    if (val.isNotEmpty && i < 5) _otpFocusNodes[i + 1].requestFocus();
    if (val.isEmpty && i > 0) _otpFocusNodes[i - 1].requestFocus();
    if (i == 5 && val.isNotEmpty) FocusScope.of(context).unfocus();
    setState(() {});
  }

  // ══════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _currentStep == 1
                  ? _buildStep1()
                  : _currentStep == 2
                      ? _buildStep2()
                      : _buildStep3(),
            ),
          ),
        ),
      ),
    );
  }

  /// Header commun à chaque étape : back arrow + titre Cormorant + sous-titre
  Widget _stepHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // Si on a sauté l'étape 1 (code pré-validé), back = quitter l'écran
              final hasPreValidated = widget.preValidatedCode != null;
              if (_currentStep > 1 && !hasPreValidated) {
                setState(() => _currentStep -= 1);
              } else if (_currentStep > 2 && hasPreValidated) {
                setState(() => _currentStep -= 1);
              } else if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
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
        Text(title, style: IOSTheme.largeTitle(context))
            .animate()
            .fadeIn(duration: 350.ms)
            .slideY(
                begin: 0.15,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutCubic),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: IOSTheme.body(context).copyWith(
            color: IOSTheme.secondaryLabel(context),
            height: 1.4,
          ),
        )
            .animate(delay: 80.ms)
            .fadeIn(duration: 350.ms),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Étape 1 ─────────────────────────────────
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepHeader(
            "Code d'église",
            "Entre le code d'invitation fourni par ton pasteur (lettres et chiffres).",
          ),

          const SizedBox(height: 12),

          Container(
            height: 64,
            decoration: BoxDecoration(
              color: IOSTheme.tertiaryBackground(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: CupertinoTextField(
              controller: _memberCodeController,
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
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                UpperCaseTextFormatter(),
              ],
              onSubmitted: (_) => _validateMemberCode(),
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 300.ms).slideY(
              begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic),

          const SizedBox(height: 28),

          _primaryButton(
            label: 'Valider',
            isLoading: _isValidatingCode,
            onTap: _isValidatingCode ? null : _validateMemberCode,
          ).animate(delay: 260.ms).fadeIn(duration: 300.ms),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Étape 2 ─────────────────────────────────
  Widget _buildStep2() {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        final green = IOSTheme.systemGreen(context);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _stepHeader(
                'Inscription',
                "Renseigne tes informations pour rejoindre l'église.",
              ),

              // ── Banner code validé ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.checkmark_seal_fill,
                        color: green, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Code validé : ${_memberCodeController.text.toUpperCase()}',
                        style: IOSTheme.footnote(context).copyWith(
                          color: IOSTheme.label(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ── Avatar picker ──
              Center(
                child: AvatarPicker(
                  file: _avatarFile,
                  size: 88,
                  onPicked: (f) => setState(() => _avatarFile = f),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _avatarFile != null
                      ? 'Toucher pour changer'
                      : 'Ajouter une photo (facultatif)',
                  style: IOSTheme.caption(context),
                ),
              ),

              const SizedBox(height: 22),

              _sectionHeader('IDENTITÉ'),
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
              ),

              const SizedBox(height: 20),

              _sectionHeader('TÉLÉPHONE'),
              const SizedBox(height: 8),
              IOSPhoneField(
                controller: _phoneController,
                onCompletePhoneChanged: (v) => _completePhoneNumber = v,
              ),

              const SizedBox(height: 20),

              _sectionHeader('QUARTIER'),
              const SizedBox(height: 8),
              _iosField(
                controller: _quartierController,
                placeholder: 'Votre quartier de résidence',
                icon: CupertinoIcons.location,
              ),

              const SizedBox(height: 20),

              _sectionHeader('DATE DE NAISSANCE'),
              const SizedBox(height: 8),
              IOSDatePickerField(
                value: _birthDate,
                placeholder: 'Sélectionner votre date de naissance',
                onChanged: (d) => setState(() => _birthDate = d),
              ),

              const SizedBox(height: 20),

              _sectionHeader('GENRE'),
              const SizedBox(height: 8),
              _genderSelector(),

              const SizedBox(height: 20),

              _sectionHeader('RÔLE'),
              const SizedBox(height: 8),
              _roleSelector(),

              if (_availableFamilies.isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionHeader('FAMILLE(S)'),
                const SizedBox(height: 8),
                if (_selectedRole == AppConstants.churchRoleResponsableFamille)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: IOSTheme.systemRed(context).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.exclamationmark_circle,
                              size: 16, color: IOSTheme.systemRed(context)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Un responsable ne peut gérer qu\'une seule famille',
                              style: IOSTheme.caption(context).copyWith(
                                color: IOSTheme.label(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                _familyList(),
              ],

              const SizedBox(height: 32),

              _primaryButton(
                label: 'Continuer',
                isLoading: auth.isLoading,
                onTap: auth.isLoading ? null : _handleSubmitForm,
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  /// Sélecteur de genre — masqué si rôle déduit (Diacre/Diaconesse)
  Widget _genderSelector() {
    final blue = IOSTheme.systemBlue(context);
    // Si rôle implique le genre, on l'affiche en lecture seule
    final impliedFromRole = _selectedRole == null
        ? null
        : AppConstants.impliedGenderForRole(_selectedRole!);
    final activeGender = impliedFromRole ?? _selectedGender;
    final locked = impliedFromRole != null;

    return Container(
      decoration: BoxDecoration(
        color: IOSTheme.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(AppConstants.allGenders.length, (i) {
          final g = AppConstants.allGenders[i];
          final isSelected = activeGender == g;
          final label = AppConstants.genderLabels[g] ?? g;
          return Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: locked
                  ? null
                  : () => setState(() => _selectedGender = g),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? blue.withValues(alpha: 0.12)
                      : CupertinoColors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      g == AppConstants.genderMale
                          ? CupertinoIcons.person_fill
                          : CupertinoIcons.person_fill,
                      color: isSelected ? blue : IOSTheme.tertiaryLabel(context),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(label,
                        style: IOSTheme.body(context).copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? IOSTheme.label(context)
                              : IOSTheme.secondaryLabel(context),
                        )),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _roleSelector() {
    final blue = IOSTheme.systemBlue(context);
    return Container(
      decoration: BoxDecoration(
        color: IOSTheme.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(AppConstants.signupChurchRoles.length, (i) {
          final role = AppConstants.signupChurchRoles[i];
          final isLast = i == AppConstants.signupChurchRoles.length - 1;
          final isSelected = _selectedRole == role;
          return Column(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _selectedRole = role;
                    // Genre auto-déduit pour Diacre (homme) / Diaconesse (femme)
                    final implied = AppConstants.impliedGenderForRole(role);
                    if (implied != null) {
                      _selectedGender = implied;
                    }
                    // Responsable famille : on contraint à 1 seule famille
                    if (role == AppConstants.churchRoleResponsableFamille &&
                        _selectedFamilyIds.length > 1) {
                      _selectedFamilyIds = [];
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppConstants.labelOfChurchRole(role),
                          style: IOSTheme.body(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        Icon(CupertinoIcons.checkmark, color: blue, size: 20),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  margin: const EdgeInsets.only(left: 14),
                  height: 0.5,
                  color: IOSTheme.separator(context),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _familyList() {
    final blue = IOSTheme.systemBlue(context);
    return Container(
      decoration: BoxDecoration(
        color: IOSTheme.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(_availableFamilies.length, (i) {
          final f = _availableFamilies[i];
          final isLast = i == _availableFamilies.length - 1;
          final selected = _selectedFamilyIds.contains(f['id']);
          return Column(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _selectedRole == null
                    ? null
                    : () {
                        setState(() {
                          if (selected) {
                            _selectedFamilyIds.remove(f['id']);
                          } else {
                            if (_selectedRole ==
                                AppConstants
                                    .churchRoleResponsableFamille) {
                              _selectedFamilyIds = [f['id']];
                            } else {
                              _selectedFamilyIds.add(f['id']);
                            }
                          }
                        });
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: selected ? blue : CupertinoColors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: selected
                                ? blue
                                : IOSTheme.tertiaryLabel(context),
                            width: 1.5,
                          ),
                        ),
                        child: selected
                            ? const Icon(CupertinoIcons.checkmark,
                                size: 14, color: CupertinoColors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(f['name'] ?? '',
                            style: IOSTheme.body(context)),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  margin: const EdgeInsets.only(left: 48),
                  height: 0.5,
                  color: IOSTheme.separator(context),
                ),
            ],
          );
        }),
      ),
    );
  }

  // ── Étape 3 ─────────────────────────────────
  Widget _buildStep3() {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        final blue = IOSTheme.systemBlue(context);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _stepHeader(
                'Vérification',
                'Entre le code à 6 chiffres reçu par SMS au $_completePhoneNumber.',
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _otpBox(i)),
              ),

              const SizedBox(height: 16),

              Center(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: auth.isLoading ? null : _handleSubmitForm,
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

              _primaryButton(
                label: "Vérifier",
                isLoading: auth.isLoading,
                onTap: auth.isLoading ? null : _handleVerifyOTP,
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _otpBox(int i) {
    final filled = _otpControllers[i].text.isNotEmpty;
    final blue = IOSTheme.systemBlue(context);
    return Container(
      width: 48,
      height: 54,
      decoration: BoxDecoration(
        color: filled
            ? blue.withValues(alpha: 0.08)
            : IOSTheme.tertiaryBackground(context),
        borderRadius: BorderRadius.circular(27), // quasi-circulaire
        border: Border.all(
          color: filled ? blue : IOSTheme.separator(context),
          width: filled ? 2 : 1.2,
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
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: filled ? blue : IOSTheme.label(context),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (val) => _onOtpChanged(i, val),
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  HELPERS UI
  // ══════════════════════════════════════════════

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: IOSTheme.sectionHeader(context).copyWith(
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

/// Force l'entrée en majuscules en temps réel.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
