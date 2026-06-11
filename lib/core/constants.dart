/*
 * FICHIER : lib/core/constants.dart
 *
 * DESCRIPTION : Constantes globales de l'application
 * Contient les valeurs fixes utilisées partout (rôles, limites, formats)
 */

class AppConstants {
  // ========== INFORMATIONS GÉNÉRALES ==========
  static const String appName = 'Claude';
  static const String appVersion = '1.0.0';

  // ========== CONFIGURATION OTP ==========
  // Longueur du code OTP (ex: 123456 = 6 chiffres)
  static const int otpLength = 6;

  // Durée de validité de l'OTP en minutes
  static const int otpExpiryMinutes = 10;

  // Nombre maximum de tentatives OTP avant blocage
  static const int maxOtpAttempts = 5;

  // ========== VALIDATION MOT DE PASSE ==========
  // Longueur minimale du mot de passe
  static const int minPasswordLength = 8;

  // ========== GESTION DES FICHIERS ==========
  // Taille maximale des images en Mo
  static const int maxImageSizeMB = 2;

  // Formats d'images acceptés
  static const List<String> acceptedImageFormats = ['jpg', 'jpeg', 'png'];

  // ========== PAGINATION ==========
  // Nombre de membres affichés par page
  static const int membersPerPage = 20;

  // Nombre de notifications par page
  static const int notificationsPerPage = 15;

  // ========== RÔLES GLOBAUX (role_global en DB) ==========
  // Rôle administrateur (créateur de l'église)
  static const String roleAdmin = 'admin';

  // Rôle membre (tous les autres utilisateurs)
  static const String roleMember = 'membre';

  // ========== RÔLES D'ÉGLISE (church_role en DB) ==========
  // Valeurs identiques à la colonne users.church_role
  // Voir migration_church_roles.sql
  static const String churchRolePasteurPrincipal   = 'pasteur_principal';
  static const String churchRolePasteurSecondaire  = 'pasteur_secondaire';
  static const String churchRoleResponsableFamille = 'responsable_famille';
  static const String churchRoleDiacre             = 'diacre';
  static const String churchRoleDiaconesse         = 'diaconesse';
  static const String churchRoleFidele             = 'fidele';

  /// Tous les rôles d'église (ordre hiérarchique)
  static const List<String> allChurchRoles = [
    churchRolePasteurPrincipal,
    churchRolePasteurSecondaire,
    churchRoleResponsableFamille,
    churchRoleDiacre,
    churchRoleDiaconesse,
    churchRoleFidele,
  ];

  /// Rôles sélectionnables à l'inscription d'un membre (exclut pasteur_principal
  /// qui est réservé à l'admin créant son église).
  static const List<String> signupChurchRoles = [
    churchRoleFidele,
    churchRoleResponsableFamille,
    churchRoleDiacre,
    churchRoleDiaconesse,
    churchRolePasteurSecondaire,
  ];

  /// Labels d'affichage des rôles d'église (côté UI)
  static const Map<String, String> churchRoleLabels = {
    churchRolePasteurPrincipal:   'Pasteur principal',
    churchRolePasteurSecondaire:  'Pasteur secondaire',
    churchRoleResponsableFamille: 'Responsable de famille',
    churchRoleDiacre:             'Diacre',
    churchRoleDiaconesse:         'Diaconesse',
    churchRoleFidele:             'Fidèle',
  };

  /// Rôles qui font partie du Comité des responsables (tous sauf fidèle)
  static const Set<String> committeeRoles = {
    churchRolePasteurPrincipal,
    churchRolePasteurSecondaire,
    churchRoleResponsableFamille,
    churchRoleDiacre,
    churchRoleDiaconesse,
  };

  /// Renvoie le label affichable d'un rôle
  static String labelOfChurchRole(String role) =>
      churchRoleLabels[role] ?? role;

  // ========== GENRE (gender en DB) ==========
  static const String genderMale   = 'homme';
  static const String genderFemale = 'femme';
  static const List<String> allGenders = [genderMale, genderFemale];
  static const Map<String, String> genderLabels = {
    genderMale:   'Homme',
    genderFemale: 'Femme',
  };

  /// Genre implicite déduit d'un rôle si possible (sinon null)
  static String? impliedGenderForRole(String role) {
    if (role == churchRoleDiacre) return genderMale;
    if (role == churchRoleDiaconesse) return genderFemale;
    return null;
  }

  // ========== ROLES LEGACY (à supprimer après refonte register_member_screen) ==========
  @Deprecated('Utiliser churchRolePasteurSecondaire')
  static const String rolePasteurSecondaire = 'Pasteur secondaire';
  @Deprecated('Utiliser churchRoleDiacre')
  static const String roleDiacre = 'Diacre';
  @Deprecated('Utiliser churchRoleDiaconesse')
  static const String roleDiaconesse = 'Diaconesse';
  @Deprecated('Utiliser churchRoleFidele')
  static const String roleFidele = 'Fidèle';
  @Deprecated('Utiliser churchRoleResponsableFamille')
  static const String roleResponsable = 'Responsable';
  @Deprecated('Utiliser allChurchRoles')
  static const List<String> memberRoles = [
    rolePasteurSecondaire,
    roleDiacre,
    roleDiaconesse,
    roleFidele,
    roleResponsable,
  ];

  // ========== TYPES DE NOTIFICATIONS ==========
  // Notification système (code membre, bienvenue, événements automatiques)
  static const String notificationTypeSystem = 'system';

  // Rapport d'appel envoyé à l'admin par un responsable après l'appel
  static const String notificationTypeAbsence = 'absence';

  // Message libre envoyé manuellement par l'admin
  static const String notificationTypeCustom = 'custom';

  // Nouvelle prédication ajoutée par l'admin
  static const String notificationTypeSermon = 'sermon';

  // ========== MESSAGES OTP SMS ==========
  // Template du SMS OTP
  static String otpSmsTemplate(String code) {
    return 'MonÉglise : Votre code de vérification est $code. Ne partagez pas ce code.';
  }

  // ========== MESSAGES DE NOTIFICATION ==========
  // Notification du code membre après inscription admin
  static String memberCodeNotification(String code) {
    return 'Votre code membre est : $code';
  }

  // Notification d'absence envoyée à l'admin
  static String absenceNotification({
    required String familyName,
    required String date,
    required int absentCount,
  }) {
    return '$date\nNOM FAMILLE : $familyName\nNombres d\'absents : $absentCount';
  }
}
