/*
 * FICHIER : lib/providers/auth_provider.dart
 *
 * DESCRIPTION : Provider pour gérer l'authentification
 * Gère le login, logout, inscription, état de connexion
 * Authentification uniquement par TÉLÉPHONE (pas d'email)
 * Utilise ChangeNotifier pour notifier les widgets des changements
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/avatar_service.dart';
import '../services/push_notifications_service.dart';
import '../supabase_config.dart';

class AuthProvider with ChangeNotifier {
  // ========== ÉTAT DE L'AUTHENTIFICATION ==========

  // Utilisateur actuellement connecté (null si déconnecté)
  UserModel? _currentUser;

  // L'app est-elle en train de charger ?
  bool _isLoading = false;

  // Message d'erreur (si une erreur survient)
  String? _errorMessage;

  /// Photo de profil sélectionnée pendant l'inscription (avant OTP) —
  /// gardée en mémoire en attendant la finalisation pour uploader.
  XFile? _pendingAvatar;

  /// Stocke la photo de profil choisie pendant le formulaire
  /// d'inscription. À appeler depuis register_admin/register_member.
  void setPendingAvatar(XFile? f) {
    _pendingAvatar = f;
  }

  // Code OTP en attente de vérification
  String? _pendingPhone;

  // ========== GETTERS ==========

  // Récupère l'utilisateur actuel
  UserModel? get currentUser => _currentUser;

  // Vérifie si un utilisateur est connecté
  bool get isAuthenticated => _currentUser != null;

  // Vérifie si l'utilisateur est admin
  bool get isAdmin => _currentUser?.roleGlobal == 'admin';

  // Récupère l'état de chargement
  bool get isLoading => _isLoading;

  // Récupère le message d'erreur
  String? get errorMessage => _errorMessage;

  // Récupère le téléphone en attente d'OTP
  String? get pendingPhone => _pendingPhone;

  // ========== CONSTRUCTEUR ==========

  AuthProvider() {
    // Mode auth direct (sans Supabase Auth) :
    // On n'utilise plus le listener onAuthStateChange parce qu'il null-erait
    // _currentUser à chaque évènement (puisqu'il n'y a JAMAIS de session
    // Supabase Auth — on gère tout dans la table `users` directement).
    //
    // Si tu réactives un jour Supabase Auth (OTP réel par exemple), ré-active
    // le listener ci-dessous mais en filtrant sur SignedIn / SignedOut events.
    //
    // SupabaseConfig.auth.onAuthStateChange.listen((data) { ... });
  }

  // ========== INITIALISATION ==========

  /*
   * Vérifie si un utilisateur est déjà connecté au démarrage
   * Appelé dans le SplashScreen
   */
  Future<void> checkAuthState() async {
    _setLoading(true);

    try {
      print('🔵 AuthProvider: Vérification de l\'état d\'authentification...');

      // Récupère l'utilisateur Supabase
      final user = SupabaseConfig.auth.currentUser;

      if (user != null) {
        print('🔵 AuthProvider: Utilisateur Supabase trouvé: ${user.id}');
        // Charge les données complètes depuis Supabase
        await _loadUserData(user.id);
      } else {
        print('🔵 AuthProvider: Aucun utilisateur Supabase connecté');
      }
    } catch (e) {
      _setError('Erreur lors de la vérification de la session');
      print('❌ AuthProvider: Erreur checkAuthState: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ========== CONNEXION ÉTAPE 1 : ENVOYER CODE OTP ==========

  /*
   * Envoie un code OTP au numéro de téléphone
   */
  Future<bool> sendOTP(String phone) async {
    _setLoading(true);
    _clearError();

    try {
      print('🔵 AuthProvider: Envoi OTP pour $phone');

      // Vérifier que l'utilisateur existe dans la base
      final userQuery = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('phone', phone)
          .limit(1);

      if (userQuery.isEmpty) {
        _setError('Aucun compte trouvé avec ce numéro');
        print('❌ AuthProvider: Aucun compte trouvé');
        return false;
      }

      // Envoyer le code OTP via Supabase
      await SupabaseConfig.auth.signInWithOtp(
        phone: phone,
      );

      _pendingPhone = phone;
      print('✅ AuthProvider: Code OTP envoyé au $phone');
      return true;

    } on AuthException catch (e) {
      print('❌ AuthProvider: Erreur Supabase Auth: ${e.message}');
      _setError(e.message);
      return false;

    } catch (e) {
      _setError('Une erreur est survenue');
      print('❌ AuthProvider: Erreur sendOTP: $e');
      return false;

    } finally {
      _setLoading(false);
    }
  }

  // ========== CONNEXION ÉTAPE 2 : VÉRIFIER CODE OTP ==========

  /*
   * Vérifie le code OTP et connecte l'utilisateur
   */
  Future<bool> verifyOTP(String code) async {
    if (_pendingPhone == null) {
      _setError('Aucun téléphone en attente de vérification');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      print('🔵 AuthProvider: Vérification OTP pour $_pendingPhone');

      // Vérifier le code OTP
      final response = await SupabaseConfig.auth.verifyOTP(
        phone: _pendingPhone!,
        token: code,
        type: OtpType.sms,
      );

      if (response.user != null) {
        print('✅ AuthProvider: Code OTP valide, connexion réussie');

        // Charge les données utilisateur
        await _loadUserData(response.user!.id);

        _pendingPhone = null;
        if (_currentUser != null) {
          // Enregistre le token FCM pour ce user (best-effort)
          unawaited(PushNotificationsService.registerTokenForUser(
              _currentUser!.id));
        }
        return true;
      }

      _setError('Code invalide');
      return false;

    } on AuthException catch (e) {
      print('❌ AuthProvider: Erreur Supabase Auth: ${e.message}');
      _setError('Code invalide ou expiré');
      return false;

    } catch (e) {
      _setError('Une erreur est survenue');
      print('❌ AuthProvider: Erreur verifyOTP: $e');
      return false;

    } finally {
      _setLoading(false);
    }
  }

  // ========== INSCRIPTION ADMIN ==========

  /*
   * Inscrit un nouvel administrateur (créateur d'église)
   * Uniquement avec téléphone, prénom, nom
   */
// ============================================================
// REMPLACEZ ces fonctions dans votre auth_provider.dart
// ============================================================

// ========== INSCRIPTION ADMIN (CORRIGÉE) ==========
  Future<String?> registerAdmin(Map<String, String> data) async {
    _setLoading(true);
    _clearError();

    try {
      print('🔵 AuthProvider: Début inscription admin...');
      print('🔵 AuthProvider: Données: ${data.keys}');

      final phone = data['phone']!;
      final firstName = data['firstName']!;
      final lastName = data['lastName']!;

      // 1. Vérifier que le numéro n'existe pas déjà (via RPC sécurisée)
      print('🔵 AuthProvider: Vérification existence du numéro...');
      final phoneExists = await SupabaseConfig.client
          .rpc('check_phone_exists', params: {'phone_number': phone});

      if (phoneExists == true) {
        _setError('Ce numéro est déjà utilisé');
        print('❌ AuthProvider: Numéro déjà utilisé');
        _setLoading(false);
        return null;
      }

      print('✅ AuthProvider: Numéro disponible');

      // 2. Envoyer un OTP pour vérifier le numéro
      print('🔵 AuthProvider: Envoi de l\'OTP...');

      await SupabaseConfig.auth.signInWithOtp(
        phone: phone,
        channel: OtpChannel.sms,
      );


      _pendingPhone = phone;

      print('✅ AuthProvider: Code OTP envoyé. En attente de vérification...');

      _setLoading(false);

      // Retourner un code spécial pour indiquer qu'on attend l'OTP
      return 'OTP_SENT';

    } on AuthException catch (e) {
      print('❌ AuthProvider: Erreur Auth: ${e.message}');
      _setError(e.message);
      _setLoading(false);
      return null;

    } catch (e, stackTrace) {
      print('❌ AuthProvider: Exception dans registerAdmin: $e');
      print('❌ AuthProvider: StackTrace: $stackTrace');
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

// ========== INSCRIPTION MEMBRE (CORRIGÉE) ==========
  Future<bool> registerMember(String memberCode, Map<String, String> data) async {
    _setLoading(true);
    _clearError();

    try {
      print('🔵 AuthProvider: Inscription membre avec code: $memberCode');

      // 1. Vérifier que le code membre existe (via RPC sécurisée)
      final codeExists = await SupabaseConfig.client
          .rpc('check_member_code_exists', params: {'code': memberCode});

      if (codeExists != true) {
        _setError('Code membre invalide');
        print('❌ AuthProvider: Code membre invalide');
        _setLoading(false);
        return false;
      }

      print('✅ AuthProvider: Code membre valide');

      final phone = data['phone']!;

      // 2. Vérifier que le numéro n'existe pas déjà (via RPC)
      final phoneExists = await SupabaseConfig.client
          .rpc('check_phone_exists', params: {'phone_number': phone});

      if (phoneExists == true) {
        _setError('Ce numéro est déjà utilisé');
        _setLoading(false);
        return false;
      }

      // 3. Envoyer un OTP pour vérifier le numéro

      await SupabaseConfig.auth.signInWithOtp(
        phone: phone,
        channel: OtpChannel.sms,
      );

      _pendingPhone = phone;

      print('✅ AuthProvider: Code OTP envoyé. En attente de vérification...');

      _setLoading(false);
      return true;

    } on AuthException catch (e) {
      print('❌ AuthProvider: Erreur Auth: ${e.message}');
      _setError(e.message);
      _setLoading(false);
      return false;

    } catch (e) {
      print('❌ AuthProvider: Exception registerMember: $e');
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

// ========== FINALISER INSCRIPTION ADMIN APRÈS OTP (IDENTIQUE) ==========
  Future<String?> finalizeAdminRegistration(String otpCode, Map<String, String> data) async {
    if (_pendingPhone == null) {
      _setError('Aucun téléphone en attente de vérification');
      return null;
    }

    _setLoading(true);

    try {
      print('🔵 AuthProvider: Finalisation inscription admin...');

      // 1. Vérifier le code OTP
      final response = await SupabaseConfig.auth.verifyOTP(
        phone: _pendingPhone!,
        token: otpCode,
        type: OtpType.sms,
      );

      if (response.user == null) {
        _setError('Code OTP invalide');
        return null;
      }

      print('✅ AuthProvider: OTP vérifié, user ID: ${response.user!.id}');

      // 2. Générer un code membre unique (6 chiffres)
      final memberCode = _generateMemberCode();

      final phone = data['phone']!;
      final firstName = data['firstName']!;
      final lastName = data['lastName']!;
      final quartier = data['quartier']!;

      final birthDate = data['birthDate']; // 'YYYY-MM-DD' ou null

      // 3. Créer le profil dans la table users
      final inserted = await SupabaseConfig.client.from('users').insert({
        'auth_id': response.user!.id,
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
        'quartier': quartier,
        'role_global': 'admin',
        'member_code': memberCode,
        if (birthDate != null && birthDate.isNotEmpty) 'birth_date': birthDate,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select('id').single();

      // 4. Upload avatar si fourni (compatible Web + mobile via XFile)
      if (_pendingAvatar != null) {
        try {
          await AvatarService.uploadAndSave(
            userId: inserted['id'] as String,
            xfile: _pendingAvatar!,
          );
        } catch (_) {}
        _pendingAvatar = null;
      }

      print('✅ AuthProvider: Profil créé avec succès');
      print('✅ AuthProvider: Code membre généré: $memberCode');

      // 5. Charge les données du nouvel utilisateur
      await _loadUserData(response.user!.id);

      _pendingPhone = null;
      return memberCode;

    } on AuthException catch (e) {
      print('❌ AuthProvider: Erreur Auth: ${e.message}');
      _setError(e.message);
      return null;

    } catch (e, stackTrace) {
      print('❌ AuthProvider: Exception dans finalizeAdminRegistration: $e');
      print('❌ AuthProvider: StackTrace: $stackTrace');
      _setError(e.toString());
      return null;

    } finally {
      _setLoading(false);
    }
  }

// ========== FINALISER INSCRIPTION MEMBRE APRÈS OTP (IDENTIQUE) ==========
  Future<bool> finalizeMemberRegistration(String otpCode, String memberCode, Map<String, String> data) async {
    if (_pendingPhone == null) {
      _setError('Aucun téléphone en attente de vérification');
      return false;
    }

    _setLoading(true);

    try {
      print('🔵 AuthProvider: Finalisation inscription membre...');

      // 1. Vérifier le code OTP
      final response = await SupabaseConfig.auth.verifyOTP(
        phone: _pendingPhone!,
        token: otpCode,
        type: OtpType.sms,
      );

      if (response.user == null) {
        _setError('Code OTP invalide');
        return false;
      }

      final phone = data['phone']!;
      final firstName = data['firstName']!;
      final lastName = data['lastName']!;
      final quartier = data['quartier'] ?? '';
      final role = data['role'];
      final churchRole = data['churchRole'] ?? 'fidele';
      final gender = data['gender'];
      final familyIdsRaw = data['familyIds'] ?? '';
      final familyIds = familyIdsRaw.isEmpty
          ? <String>[]
          : familyIdsRaw.split(',').where((s) => s.isNotEmpty).toList();

      // 2. Récupérer l'admin via son member_code → on en déduit le church_id
      final adminLookup = await SupabaseConfig.client
          .from('users')
          .select('id, church_id')
          .eq('member_code', memberCode.toUpperCase())
          .eq('role_global', 'admin')
          .single();

      final churchId = adminLookup['church_id'] as String?;

      final birthDate = data['birthDate'];

      // 3. Créer le profil dans la table users
      final inserted = await SupabaseConfig.client.from('users').insert({
        'auth_id':     response.user!.id,
        'phone':       phone,
        'first_name':  firstName,
        'last_name':   lastName,
        'quartier':    quartier,
        'role_global': 'membre',
        'role':        role,
        'church_role': churchRole,
        if (gender != null) 'gender': gender,
        'church_id':   churchId,
        'admin_code':  memberCode,
        // family_ids n'est PLUS écrit — voir table family_members
        if (birthDate != null && birthDate.isNotEmpty) 'birth_date': birthDate,
        'created_at':  DateTime.now().toIso8601String(),
        'updated_at':  DateTime.now().toIso8601String(),
      }).select('id').single();

      // ⚡ Le trigger sync_church_role ajoutera automatiquement ce user au
      // Comité des responsables si son church_role est ≠ 'fidele'.

      // Pour les "responsable_famille", on les marque comme responsable de
      // la famille sélectionnée (qui devient leur "famille principale").
      if (churchRole == 'responsable_famille' && familyIds.isNotEmpty) {
        try {
          await SupabaseConfig.client
              .from('families')
              .update({'responsible_id': inserted['id']})
              .eq('id', familyIds.first);
        } catch (e) {
          print('⚠️ Impossible de marquer responsable_id: $e');
        }
      }

      // Liaison user ↔ familles via la table de jointure (source de vérité)
      if (familyIds.isNotEmpty) {
        await SupabaseConfig.client.from('family_members').insert(
              familyIds
                  .map((fid) =>
                      {'family_id': fid, 'user_id': inserted['id']})
                  .toList(),
            );
      }

      // 3.b. Upload avatar si fourni (compatible Web + mobile)
      if (_pendingAvatar != null) {
        try {
          await AvatarService.uploadAndSave(
            userId: inserted['id'] as String,
            xfile: _pendingAvatar!,
          );
        } catch (_) {}
        _pendingAvatar = null;
      }

      // 4. Ajouter le nouvel utilisateur dans les familles sélectionnées
      //    via la table de jointure family_members (single source of truth).
      final newUserId = inserted['id'] as String;
      if (familyIds.isNotEmpty) {
        try {
          await SupabaseConfig.client.from('family_members').upsert(
            familyIds
                .map((fid) => {'family_id': fid, 'user_id': newUserId})
                .toList(),
            onConflict: 'family_id,user_id',
          );
        } catch (_) {}
      }

      print('✅ AuthProvider: Inscription membre réussie');

      // 5. Charge les données du nouvel utilisateur
      await _loadUserData(response.user!.id);

      _pendingPhone = null;
      return true;

    } on AuthException catch (e) {
      print('❌ AuthProvider: Erreur Auth: ${e.message}');
      _setError(e.message);
      return false;

    } catch (e, stackTrace) {
      print('❌ AuthProvider: Exception finalizeMemberRegistration: $e');
      print('❌ AuthProvider: StackTrace: $stackTrace');
      _setError(e.toString());
      return false;

    } finally {
      _setLoading(false);
    }
  }

// ========== CHARGEMENT DONNÉES UTILISATEUR (CORRIGÉ) ==========
  Future<void> _loadUserData(String authUserId) async {
    try {
      print('🔵 AuthProvider: Chargement données pour auth_id: $authUserId');

      final data = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('auth_id', authUserId)
          .single();

      _currentUser = UserModel.fromSupabase(
        data,
      );

      print('✅ AuthProvider: Données utilisateur chargées: ${_currentUser?.fullName}');
      notifyListeners();

    } catch (e) {
      print('❌ AuthProvider: Erreur chargement utilisateur: $e');
      throw Exception('Impossible de charger les données utilisateur');
    }
  }
  // ========== DÉCONNEXION ==========

  /*
   * Déconnecte l'utilisateur actuel
   */
  Future<void> logout() async {
    _setLoading(true);

    try {
      print('🔵 AuthProvider: Déconnexion...');
      if (_currentUser != null) {
        await PushNotificationsService.unregisterTokenForUser(_currentUser!.id);
      }
      await SupabaseConfig.auth.signOut();
      _currentUser = null;
      _pendingPhone = null;
      notifyListeners();
      print('✅ AuthProvider: Déconnexion réussie');

    } catch (e) {
      _setError('Erreur lors de la déconnexion');
      print('❌ AuthProvider: Erreur logout: $e');

    } finally {
      _setLoading(false);
    }
  }

  // ========== CHARGEMENT DONNÉES UTILISATEUR ==========

  /*
   * Charge les données complètes de l'utilisateur depuis Supabase
   */
// ========== CHARGEMENT DONNÉES UTILISATEUR (CORRIGÉ) ==========


  // ========== MISE À JOUR PROFIL ==========

  /*
   * Met à jour les informations du profil utilisateur
   */
  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? quartier,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return false;

    _setLoading(true);

    try {
      // Prépare les données à mettre à jour
      Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (firstName != null) updates['first_name'] = firstName;
      if (lastName != null) updates['last_name'] = lastName;
      if (quartier != null) updates['quartier'] = quartier;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      // Met à jour dans Supabase
      await SupabaseConfig.client
          .from('users')
          .update(updates)
          .eq('auth_id', _currentUser!.authId);  // ✅ Changé de id vers authId

      // Recharge les données
      await _loadUserData(_currentUser!.authId);  // ✅ Changé de id vers authId
      // ...

      return true;

    } catch (e) {
      _setError('Erreur lors de la mise à jour');
      print('❌ AuthProvider: Erreur updateProfile: $e');
      return false;

    } finally {
      _setLoading(false);
    }
  }

  /// Recharge les données du user courant depuis la DB.
  /// Utile après un changement de profil (avatar, etc.).
  /// Lit par `id` (toujours présent) plutôt que `auth_id` (null en mode DEV bypass).
  /// Si la row n'existe pas en DB, on garde le _currentUser local mais on signale.
  Future<void> refreshUser() async {
    if (_currentUser == null) return;
    try {
      final data = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('id', _currentUser!.id)
          .maybeSingle();
      if (data != null) {
        _currentUser = UserModel.fromSupabase(data);
      }
      notifyListeners();
    } catch (e) {
      // ignore: avoid_print
      print('❌ refreshUser: $e');
      // On ne rethrow pas — au pire on garde le _currentUser local
      notifyListeners();
    }
  }

  /// Met à jour uniquement l'URL avatar dans le user en mémoire (sans appel DB).
  /// Utile pour rafraîchir l'UI après un upload réussi.
  void updateLocalAvatarUrl(String url) {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(avatarUrl: url);
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════
  //  CHANGEMENT DE NUMÉRO DE TÉLÉPHONE (avec OTP)
  // ══════════════════════════════════════════════════════════════════════

  /// Étape 1 : demande à Supabase d'envoyer un OTP au NOUVEAU numéro.
  /// Tant que l'OTP n'est pas vérifié, l'ancien numéro reste actif.
  Future<bool> requestPhoneChange(String newPhone) async {
    if (_currentUser == null) {
      _setError('Aucun utilisateur connecté');
      return false;
    }
    _setLoading(true);
    _clearError();
    try {
      // Vérifie d'abord que ce numéro n'est pas déjà utilisé par un autre user
      final exists = await SupabaseConfig.client
          .rpc('check_phone_exists', params: {'phone_number': newPhone});
      if (exists == true) {
        _setError('Ce numéro est déjà utilisé');
        return false;
      }

      // Demande à Supabase Auth d'envoyer l'OTP au nouveau numéro
      await SupabaseConfig.auth.updateUser(
        UserAttributes(phone: newPhone),
      );

      _pendingPhone = newPhone;
      print('✅ AuthProvider: OTP envoyé au nouveau numéro $newPhone');
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError("Impossible d'envoyer le code");
      print('❌ AuthProvider: requestPhoneChange: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Étape 2 : vérifie l'OTP saisi par l'utilisateur et confirme le changement.
  Future<bool> confirmPhoneChange(String otpCode) async {
    if (_pendingPhone == null) {
      _setError('Aucun numéro en attente de vérification');
      return false;
    }
    _setLoading(true);
    _clearError();
    try {
      final res = await SupabaseConfig.auth.verifyOTP(
        phone: _pendingPhone!,
        token: otpCode,
        type: OtpType.phoneChange,
      );

      if (res.user == null) {
        _setError('Code invalide');
        return false;
      }

      // Met aussi à jour la table publique users
      await SupabaseConfig.client
          .from('users')
          .update({'phone': _pendingPhone}).eq('id', _currentUser!.id);

      await _loadUserData(_currentUser!.authId);
      _pendingPhone = null;
      return true;
    } on AuthException catch (_) {
      _setError('Code incorrect ou expiré');
      return false;
    } catch (e) {
      _setError('Impossible de valider le code');
      print('❌ AuthProvider: confirmPhoneChange: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  AUTH DIRECTE — SANS OTP SMS (mode communauté privée / APK uniquement)
  // ══════════════════════════════════════════════════════════════════════
  //
  // Important : on shortcut Supabase Auth (auth.users). Tous les inserts dans
  // public.users ont auth_id = NULL. La persistance entre 2 lancements de
  // l'app passe par SharedPreferences (clé `current_user_id`).
  //
  // Cette section remplace verifyOTP / finalize*Registration pour les flows
  // qui veulent éviter le SMS.

  static const String _prefsCurrentUserKey = 'mon_eglise_current_user_id';

  /// Login par numéro de téléphone uniquement.
  /// Retourne true si un user avec ce numéro existe et a été chargé.
  Future<bool> loginByPhone(String phone) async {
    _setLoading(true);
    _clearError();
    try {
      final data = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('phone', phone)
          .maybeSingle();
      if (data == null) {
        _setError('Numéro non reconnu. Inscrivez-vous d\'abord.');
        return false;
      }
      _currentUser = UserModel.fromSupabase(Map<String, dynamic>.from(data));
      await _persistCurrentUser();
      notifyListeners();
      unawaited(
          PushNotificationsService.registerTokenForUser(_currentUser!.id));
      _subscribeToCurrentUser();
      return true;
    } catch (e) {
      _setError('Erreur de connexion : $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Inscription directe d'un membre (sans OTP).
  /// `data` doit contenir : firstName, lastName, phone, quartier, churchRole,
  ///   gender, familyIds (CSV), birthDate (optionnel).
  /// `memberCode` = code de l'admin de l'église.
  Future<bool> registerMemberDirect({
    required String memberCode,
    required Map<String, String> data,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      // 1. Vérifie que le numéro n'est pas déjà pris
      final phone = data['phone']!;
      final dup = await SupabaseConfig.client
          .from('users')
          .select('id')
          .eq('phone', phone)
          .maybeSingle();
      if (dup != null) {
        _setError('Ce numéro est déjà enregistré.');
        return false;
      }

      // 2. Récupère church_id depuis le code admin
      final adminLookup = await SupabaseConfig.client
          .from('users')
          .select('id, church_id')
          .eq('member_code', memberCode.toUpperCase())
          .eq('role_global', 'admin')
          .single();
      final churchId = adminLookup['church_id'] as String?;
      if (churchId == null) {
        _setError("Église introuvable pour ce code.");
        return false;
      }

      final churchRole = data['churchRole'] ?? 'fidele';
      final gender = data['gender'];
      final familyIdsRaw = data['familyIds'] ?? '';
      final familyIds = familyIdsRaw.isEmpty
          ? <String>[]
          : familyIdsRaw.split(',').where((s) => s.isNotEmpty).toList();
      final birthDate = data['birthDate'];

      // 3. INSERT direct dans users (auth_id = null)
      final inserted = await SupabaseConfig.client.from('users').insert({
        'auth_id':     null,
        'phone':       phone,
        'first_name':  data['firstName']!,
        'last_name':   data['lastName']!,
        'quartier':    data['quartier'] ?? '',
        'role_global': 'membre',
        'role':        data['role'] ?? churchRole,
        'church_role': churchRole,
        if (gender != null) 'gender': gender,
        'church_id':   churchId,
        'admin_code':  memberCode.toUpperCase(),
        if (birthDate != null && birthDate.isNotEmpty) 'birth_date': birthDate,
        'created_at':  DateTime.now().toIso8601String(),
        'updated_at':  DateTime.now().toIso8601String(),
      }).select().single();
      final newUserId = inserted['id'] as String;

      // 4. Liaison familles
      if (familyIds.isNotEmpty) {
        await SupabaseConfig.client.from('family_members').insert(
              familyIds
                  .map((fid) => {'family_id': fid, 'user_id': newUserId})
                  .toList(),
            );
        // Si responsable_famille → marquer responsible_id sur la famille
        if (churchRole == 'responsable_famille') {
          try {
            await SupabaseConfig.client
                .from('families')
                .update({'responsible_id': newUserId})
                .eq('id', familyIds.first);
          } catch (_) {}
        }
      }

      // 5. Avatar si fourni
      if (_pendingAvatar != null) {
        try {
          await AvatarService.uploadAndSave(
            userId: newUserId,
            xfile: _pendingAvatar!,
          );
        } catch (_) {}
        _pendingAvatar = null;
      }

      // 6. Auto-login
      _currentUser = UserModel.fromSupabase(Map<String, dynamic>.from(inserted));
      await _persistCurrentUser();
      notifyListeners();
      unawaited(PushNotificationsService.registerTokenForUser(newUserId));
      _subscribeToCurrentUser();
      return true;
    } catch (e) {
      _setError("Inscription impossible : $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Inscription directe d'un admin (sans OTP).
  /// `data` doit contenir : firstName, lastName, phone, quartier,
  ///   gender (optionnel), birthDate (optionnel).
  /// Crée juste le user admin — l'église sera créée ensuite par
  /// `ChurchSetupModal`. Retourne le member_code généré.
  Future<String?> registerAdminDirect({
    required Map<String, String> data,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final phone = data['phone']!;
      // 1. Vérifie unicité
      final dup = await SupabaseConfig.client
          .from('users')
          .select('id')
          .eq('phone', phone)
          .maybeSingle();
      if (dup != null) {
        _setError('Ce numéro est déjà enregistré.');
        return null;
      }

      final memberCode = _generateMemberCode();
      final gender = data['gender'];
      final birthDate = data['birthDate'];

      // 2. Insère le user admin (church_id sera défini par ChurchSetupModal)
      final userInserted = await SupabaseConfig.client.from('users').insert({
        'auth_id':       null,
        'phone':         phone,
        'first_name':    data['firstName']!,
        'last_name':     data['lastName']!,
        'quartier':      data['quartier'] ?? '',
        'role_global':   'admin',
        'church_role':   'pasteur_principal',
        if (gender != null) 'gender': gender,
        'member_code':   memberCode,
        'is_responsible': true,
        if (birthDate != null && birthDate.isNotEmpty) 'birth_date': birthDate,
        'created_at':    DateTime.now().toIso8601String(),
        'updated_at':    DateTime.now().toIso8601String(),
      }).select().single();
      final adminId = userInserted['id'] as String;

      // 3. Avatar si fourni
      if (_pendingAvatar != null) {
        try {
          await AvatarService.uploadAndSave(
            userId: adminId,
            xfile: _pendingAvatar!,
          );
        } catch (_) {}
        _pendingAvatar = null;
      }

      // 4. Auto-login avec re-fetch pour avoir l'avatar
      final finalRow = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('id', adminId)
          .single();
      _currentUser = UserModel.fromSupabase(Map<String, dynamic>.from(finalRow));
      await _persistCurrentUser();
      notifyListeners();
      unawaited(PushNotificationsService.registerTokenForUser(adminId));
      _subscribeToCurrentUser();
      return memberCode;
    } catch (e) {
      _setError("Inscription admin impossible : $e");
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Persiste l'ID du user courant en SharedPreferences pour auto-login.
  Future<void> _persistCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        await prefs.setString(_prefsCurrentUserKey, _currentUser!.id);
      } else {
        await prefs.remove(_prefsCurrentUserKey);
      }
    } catch (_) {}
  }

  /// Tente l'auto-login depuis l'ID stocké en SharedPreferences.
  /// Retourne true si réussi.
  Future<bool> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_prefsCurrentUserKey);
      if (id == null || id.isEmpty) return false;
      final data = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (data == null) {
        await prefs.remove(_prefsCurrentUserKey);
        return false;
      }
      _currentUser = UserModel.fromSupabase(Map<String, dynamic>.from(data));
      notifyListeners();
      unawaited(PushNotificationsService.registerTokenForUser(id));
      _subscribeToCurrentUser();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Channel Realtime pour suivre les changements du currentUser.
  /// Utile quand l'admin change le rôle / avatar / etc. du user → l'app
  /// du user concerné se met à jour automatiquement sans refresh manuel.
  RealtimeChannel? _currentUserChannel;

  void _subscribeToCurrentUser() {
    final user = _currentUser;
    if (user == null) return;
    _currentUserChannel?.unsubscribe();
    _currentUserChannel = SupabaseConfig.client
        .channel('current_user_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: user.id,
          ),
          callback: (payload) async {
            // Re-fetch le user complet (le payload n'a pas toutes les colonnes
            // selon la config Realtime)
            try {
              final data = await SupabaseConfig.client
                  .from('users')
                  .select()
                  .eq('id', user.id)
                  .maybeSingle();
              if (data != null) {
                _currentUser =
                    UserModel.fromSupabase(Map<String, dynamic>.from(data));
                notifyListeners();
              }
            } catch (_) {}
          },
        )
        .subscribe();
  }

  /// Logout simplifié (sans Supabase Auth).
  Future<void> logoutDirect() async {
    if (_currentUser != null) {
      try {
        await PushNotificationsService.unregisterTokenForUser(_currentUser!.id);
      } catch (_) {}
    }
    _currentUserChannel?.unsubscribe();
    _currentUserChannel = null;
    _currentUser = null;
    await _persistCurrentUser();
    notifyListeners();
  }

  // ========== MÉTHODES UTILITAIRES PRIVÉES ==========

  // Génère un code membre unique à 6 chiffres
  String _generateMemberCode() {
    return (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
  }

  // Active/désactive l'état de chargement
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Définit un message d'erreur
  void _setError(String message) {
    _errorMessage = message;
    print('❌ AuthProvider: Erreur définie: $message');
    notifyListeners();
  }

  // Efface le message d'erreur
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}