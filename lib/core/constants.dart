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

  // ========== RÔLES GLOBAUX ==========
  // Rôle administrateur (créateur de l'église)
  static const String roleAdmin = 'admin';

  // Rôle membre (tous les autres utilisateurs)
  static const String roleMember = 'membre';

  // ========== RÔLES SPÉCIFIQUES DES MEMBRES ==========
  // Pasteur secondaire (autorité spirituelle)
  static const String rolePasteurSecondaire = 'Pasteur secondaire';

  // Diacre (homme servant l'église)
  static const String roleDiacre = 'Diacre';

  // Diaconesse (femme servant l'église)
  static const String roleDiaconesse = 'Diaconesse';

  // Fidèle (membre ordinaire, peut appartenir à plusieurs familles)
  static const String roleFidele = 'Fidèle';

  // Responsable (chef d'une famille, peut faire l'appel)
  static const String roleResponsable = 'Responsable';

  // Liste de tous les rôles disponibles pour les membres
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
