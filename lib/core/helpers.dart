
/*
 * FICHIER : lib/core/helpers.dart
 *
 * DESCRIPTION : Fonctions utilitaires diverses
 */

import 'dart:math';
import 'package:intl/intl.dart';

import 'constants.dart';

class Helpers {
  // ========== GÉNÉRATION CODE MEMBRE ==========
  // Génère un code aléatoire de 8 caractères (ex: ABCD1234)
  static String generateMemberCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();

    return List.generate(
      8,
          (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // ========== GÉNÉRATION CODE OTP ==========
  // Génère un code OTP de 6 chiffres (ex: 123456)
  static String generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // ========== FORMATAGE DE DATE ==========
  // Convertit une date en format lisible (ex: "Dimanche 22 mars 2024")
  static String formatDate(DateTime date) {
    final formatter = DateFormat('EEEE dd MMMM yyyy', 'fr_FR');
    return formatter.format(date);
  }

  // Convertit en format court (ex: "22/03/2024")
  static String formatDateShort(DateTime date) {
    final formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(date);
  }

  // ========== FORMATAGE NUMÉRO DE TÉLÉPHONE ==========
  // Ajoute +225 si absent
  static String formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (!cleaned.startsWith('225')) {
      cleaned = '225$cleaned';
    }

    return '+$cleaned';
  }

  // ========== VALIDATION TAILLE IMAGE ==========
  // Vérifie qu'une image ne dépasse pas la taille max
  static bool isImageSizeValid(int sizeInBytes) {
    int sizeInMB = sizeInBytes ~/ (1024 * 1024);
    return sizeInMB <= AppConstants.maxImageSizeMB;
  }

  // ========== INITIALES POUR AVATAR ==========
  // Extrait les initiales d'un nom complet (ex: "Jean Kouassi" -> "JK")
  static String getInitials(String fullName) {
    List<String> names = fullName.trim().split(' ');

    if (names.isEmpty) return '?';
    if (names.length == 1) return names[0][0].toUpperCase();

    return (names[0][0] + names[names.length - 1][0]).toUpperCase();
  }
}

/*
 * UTILISATION DES CONSTANTES ET HELPERS :
 *
 * Import dans vos fichiers :
 * import 'package:moneglise/core/constants.dart';
 * import 'package:moneglise/core/validators.dart';
 * import 'package:moneglise/core/helpers.dart';
 *
 * Exemples :
 * - String role = AppConstants.roleFidele;
 * - String? error = Validators.validatePhone('+2250708090807');
 * - String code = Helpers.generateMemberCode();
 */