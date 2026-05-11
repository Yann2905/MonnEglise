/*
 * FICHIER : lib/services/auth_service.dart
 *
 * DESCRIPTION : Service utilitaire pour l'authentification Supabase
 * Utilise l'authentification par TÉLÉPHONE uniquement avec OTP
 *
 * NOTE : La logique principale est maintenant dans auth_provider.dart
 * Ce service sert de couche utilitaire pour des opérations spécifiques
 */

import '../supabase_config.dart';
import '../core/helpers.dart';
import '../core/constants.dart';

class AuthService {
  // =================== VALIDATION CODE MEMBRE ===================
  /*
   * Vérifie si le code membre fourni correspond à un administrateur existant
   * Retourne l'ID de l'administrateur associé si valide
   * Retourne null si le code est invalide
   */
  Future<String?> validateMemberCode(String memberCode) async {
    try {
      // Normalise le code pour éviter les erreurs de casse
      String normalizedCode = memberCode.toUpperCase();

      // Requête Supabase pour chercher l'admin avec ce code
      final response = await SupabaseConfig.client
          .from('users')
          .select('id')
          .eq('member_code', normalizedCode)
          .eq('role_global', AppConstants.roleAdmin)
          .limit(1);

      if (response.isNotEmpty) {
        // Code valide : retourne l'ID admin
        return response.first['id'];
      } else {
        // Code invalide
        return null;
      }
    } catch (e) {
      print('❌ Erreur validateMemberCode: $e');
      return null;
    }
  }

  /// Résout un code (invite_code église OU member_code admin) en `adminId`.
  /// Essaie d'abord le code d'invitation d'église, puis le code membre legacy.
  /// Retourne null si aucun ne correspond.
  Future<String?> resolveJoinCode(String rawCode) async {
    final normalized = rawCode.toUpperCase().trim();

    // 1. Essayer invite_code d'église (nouveau système)
    try {
      final r = await SupabaseConfig.client
          .rpc('lookup_church_by_invite_code', params: {'code': normalized});
      if (r is List && r.isNotEmpty) {
        final row = r.first as Map;
        final adminId = row['admin_id']?.toString();
        if (adminId != null && adminId.isNotEmpty) return adminId;
      }
    } catch (_) {}

    // 2. Fallback sur member_code admin (legacy)
    return validateMemberCode(normalized);
  }

  // =================== VÉRIFIER SI TÉLÉPHONE EXISTE ===================
  /*
   * Vérifie si un numéro de téléphone est déjà enregistré
   * Retourne true si le numéro existe, false sinon
   */
  Future<bool> phoneExists(String phoneNumber) async {
    try {
      final response = await SupabaseConfig.client
          .from('users')
          .select('id')
          .eq('phone', phoneNumber)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      print('❌ Erreur phoneExists: $e');
      return false;
    }
  }

  // =================== RÉCUPÉRER EMAIL PAR TÉLÉPHONE ===================
  /*
   * Récupère l'email associé à un numéro de téléphone
   * (Utile si vous décidez d'ajouter l'email plus tard)
   * Retourne null si non trouvé
   */
  Future<String?> getEmailByPhone(String phoneNumber) async {
    try {
      final response = await SupabaseConfig.client
          .from('users')
          .select('email')
          .eq('phone', phoneNumber)
          .limit(1);

      if (response.isNotEmpty) {
        return response.first['email'];
      }
      return null;
    } catch (e) {
      print('❌ Erreur getEmailByPhone: $e');
      return null;
    }
  }

  // =================== RÉCUPÉRER UTILISATEUR PAR TÉLÉPHONE ===================
  /*
   * Récupère les données complètes d'un utilisateur par son téléphone
   * Retourne les données ou null si non trouvé
   */
  Future<Map<String, dynamic>?> getUserByPhone(String phoneNumber) async {
    try {
      final response = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('phone', phoneNumber)
          .limit(1);

      if (response.isNotEmpty) {
        return response.first;
      }
      return null;
    } catch (e) {
      print('❌ Erreur getUserByPhone: $e');
      return null;
    }
  }

  // =================== ENVOYER NOTIFICATION SYSTÈME ===================
  /*
   * Envoie une notification système à un utilisateur
   * Utile pour notifier des événements importants
   */
  Future<void> sendSystemNotification({
    required String userId,
    required String title,
    required String message,
  }) async {
    try {
      await SupabaseConfig.client.from('notifications').insert({
        'title': title,
        'message': message,
        'type': AppConstants.notificationTypeSystem,
        'sender_id': 'system',
        'receiver_id': userId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('⚠️ Erreur notification non critique: $e');
    }
  }

  // =================== ENVOYER NOTIFICATION CODE MEMBRE ===================
  /*
   * Envoie une notification avec le code membre à l'admin
   */
  Future<void> sendMemberCodeNotification(String userId, String code) async {
    try {
      await sendSystemNotification(
        userId: userId,
        title: 'Code Membre',
        message: AppConstants.memberCodeNotification(code),
      );
    } catch (e) {
      print('⚠️ Erreur notification code membre: $e');
    }
  }

  // =================== VÉRIFIER DISPONIBILITÉ CODE MEMBRE ===================
  /*
   * Vérifie si un code membre est disponible (non utilisé)
   * Retourne true si disponible, false si déjà pris
   */
  Future<bool> isMemberCodeAvailable(String memberCode) async {
    try {
      final response = await SupabaseConfig.client
          .from('users')
          .select('id')
          .eq('member_code', memberCode.toUpperCase())
          .limit(1);

      // Si aucune réponse, le code est disponible
      return response.isEmpty;
    } catch (e) {
      print('❌ Erreur isMemberCodeAvailable: $e');
      return false;
    }
  }

  // =================== GÉNÉRER CODE MEMBRE UNIQUE ===================
  /*
   * Génère un code membre unique qui n'existe pas encore dans la base
   * Retourne un code à 6 chiffres
   */
  Future<String> generateUniqueMemberCode() async {
    String code;
    bool isAvailable = false;
    int attempts = 0;
    const maxAttempts = 10;

    do {
      code = Helpers.generateMemberCode();
      isAvailable = await isMemberCodeAvailable(code);
      attempts++;

      if (attempts >= maxAttempts) {
        throw Exception('Impossible de générer un code membre unique');
      }
    } while (!isAvailable);

    return code;
  }

  // =================== METTRE À JOUR DERNIÈRE CONNEXION ===================
  /*
   * Met à jour la date de dernière connexion de l'utilisateur
   */
  Future<void> updateLastLogin(String userId) async {
    try {
      await SupabaseConfig.client
          .from('users')
          .update({
        'last_login': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', userId);
    } catch (e) {
      print('⚠️ Erreur updateLastLogin: $e');
    }
  }

  // =================== COMPTER MEMBRES PAR ADMIN ===================
  /*
   * Compte le nombre de membres associés à un admin
   * Utile pour des statistiques
   */
  Future<int> countMembersByAdmin(String adminId) async {
    try {
      final response = await SupabaseConfig.client
          .from('users')
          .select('id')
          .eq('admin_code', adminId)
          .eq('role_global', AppConstants.roleMember);
      return response.length;
    } catch (e) {
      print('❌ Erreur countMembersByAdmin: $e');
      return 0;
    }
  }

  // =================== VÉRIFIER SI UTILISATEUR EST ADMIN ===================
  /*
   * Vérifie rapidement si un utilisateur est admin
   */
  Future<bool> isUserAdmin(String userId) async {
    try {
      final response = await SupabaseConfig.client
          .from('users')
          .select('role_global')
          .eq('id', userId)
          .limit(1);

      if (response.isNotEmpty) {
        return response.first['role_global'] == AppConstants.roleAdmin;
      }
      return false;
    } catch (e) {
      print('❌ Erreur isUserAdmin: $e');
      return false;
    }
  }
}

/*
 * ============================================================
 * NOTES D'UTILISATION
 * ============================================================
 *
 * Ce service est maintenant beaucoup plus simple car :
 *
 * 1. L'inscription admin/membre est gérée dans auth_provider.dart
 * 2. L'envoi et vérification OTP sont gérés par Supabase Auth directement
 * 3. Plus besoin de documents temporaires
 *
 * Ce service sert maintenant uniquement pour :
 * - Valider les codes membres
 * - Vérifier l'existence de téléphones
 * - Envoyer des notifications
 * - Faire des requêtes utilitaires
 *
 * ============================================================
 * MIGRATION DEPUIS L'ANCIEN CODE
 * ============================================================
 *
 * Si votre code appelait :
 *
 * AVANT :
 * await authService.registerAdmin(data);
 * await authService.registerMember(code, data);
 * await authService.sendOtpCode(phone);
 * await authService.verifyOtpCode(vId, code);
 *
 * MAINTENANT :
 * await authProvider.registerAdmin(data);
 * await authProvider.registerMember(code, data);
 * await authProvider.sendOTP(phone);
 * await authProvider.verifyOTP(code);
 *
 * (Utilisez le provider au lieu du service)
 *
 * ============================================================
 */