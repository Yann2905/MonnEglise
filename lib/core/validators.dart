
/*
 * FICHIER : lib/core/validators.dart
 *
 * DESCRIPTION : Fonctions de validation pour les formulaires
 * Valide numéros de téléphone, mots de passe, emails, etc.
 */

import 'constants.dart';

class Validators {
  // ========== VALIDATION NUMÉRO DE TÉLÉPHONE ==========
  // Vérifie que le numéro est au format ivoirien (+225XXXXXXXX)
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le numéro de téléphone est requis';
    }

    // Retire les espaces et caractères spéciaux
    String cleaned = value.replaceAll(RegExp(r'[^\d+]'), '');

    // Vérifie le format (+225 + 10 chiffres)
    if (!RegExp(r'^\+225\d{10}$').hasMatch(cleaned)) {
      return 'Format invalide. Utilisez +225XXXXXXXXXX';
    }

    return null; // Pas d'erreur
  }

  // ========== VALIDATION MOT DE PASSE ==========
  // Vérifie longueur minimale et complexité
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }

    if (value.length < AppConstants.minPasswordLength) {
      return 'Le mot de passe doit contenir au moins ${AppConstants.minPasswordLength} caractères';
    }

    // Optionnel : vérifier présence de majuscule, chiffre, caractère spécial
    // if (!RegExp(r'[A-Z]').hasMatch(value)) {
    //   return 'Le mot de passe doit contenir au moins une majuscule';
    // }

    return null;
  }

  // ========== VALIDATION CONFIRMATION MOT DE PASSE ==========
  static String? validatePasswordConfirmation(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Veuillez confirmer le mot de passe';
    }

    if (value != password) {
      return 'Les mots de passe ne correspondent pas';
    }

    return null;
  }

  // ========== VALIDATION NOM/PRÉNOM ==========
  // Vérifie que le nom contient au moins 2 caractères
  static String? validateName(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }

    if (value.length < 2) {
      return '$fieldName doit contenir au moins 2 caractères';
    }

    return null;
  }

  // ========== VALIDATION CODE OTP ==========
  // Vérifie que le code contient exactement 6 chiffres
  static String? validateOtp(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le code OTP est requis';
    }

    if (value.length != AppConstants.otpLength) {
      return 'Le code doit contenir ${AppConstants.otpLength} chiffres';
    }

    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'Le code doit contenir uniquement des chiffres';
    }

    return null;
  }

  // ========== VALIDATION CODE MEMBRE ==========
  // Vérifie le format du code membre (8 caractères alphanumériques)
  static String? validateMemberCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le code membre est requis';
    }

    if (value.length != 8) {
      return 'Le code membre doit contenir 8 caractères';
    }

    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(value.toUpperCase())) {
      return 'Code invalide';
    }

    return null;
  }

  // ========== VALIDATION QUARTIER ==========
  static String? validateQuartier(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le quartier est requis';
    }

    return null;
  }
}
