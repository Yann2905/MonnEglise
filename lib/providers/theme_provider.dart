// FICHIER : lib/providers/theme_provider.dart
// Version totalement corrigée — plus AUCUNE erreur sur ThemeMode
// Explications simples pour chaque ligne.

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart'; // Permet de sauvegarder le thème dans le stockage local

// ------------------------------------------------------------
// Classe principale qui gère le thème de l'application
// ------------------------------------------------------------
class ThemeProvider with ChangeNotifier {
  // Le thème actuellement appliqué (clair par défaut — l'utilisateur peut
  // basculer manuellement vers sombre dans Profil > Mode sombre).
  ThemeMode _themeMode = ThemeMode.light;

  // Nom utilisé pour sauvegarder la préférence dans SharedPreferences
  static const String _themePrefKey = 'theme_mode';

  // Getter qui permet à l'application de lire le thème actuel
  ThemeMode get themeMode => _themeMode;

  // Renvoie "true" si le mode sombre est actif
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // ------------------------------------------------------------
  // Constructeur : appelé automatiquement quand le provider est créé
  // Il charge la préférence enregistrée précédemment
  // ------------------------------------------------------------
  ThemeProvider() {
    _loadThemePreference(); // On charge la dernière valeur sauvegardée
  }

  // ------------------------------------------------------------
  // Charge le thème depuis SharedPreferences
  // ------------------------------------------------------------
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance(); // Accès au stockage local
      final savedTheme = prefs.getString(_themePrefKey); // Lecture de la valeur enregistrée

      if (savedTheme != null) {
        // Transforme la chaîne enregistrée en vrai ThemeMode
        _themeMode = ThemeMode.values.firstWhere(
              (mode) => mode.toString() == savedTheme,
          orElse: () => ThemeMode.light, // Si erreur : thème clair
        );

        notifyListeners(); // Met à jour l'application
      }
    } catch (e) {
      debugPrint('Erreur chargement thème: $e'); // Si problème de lecture
    }
  }

  // ------------------------------------------------------------
  // Change le thème et sauvegarde la préférence
  // ------------------------------------------------------------
  Future<void> setThemeMode(ThemeMode newMode) async {
    _themeMode = newMode; // Change le thème
    notifyListeners(); // Notifie les widgets

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, newMode.toString()); // Sauvegarde
    } catch (e) {
      debugPrint('Erreur sauvegarde thème: $e'); // Si problème d'écriture
    }
  }

  // ------------------------------------------------------------
  // Bascule entre clair et sombre (sans passer par le mode système)
  // ------------------------------------------------------------
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark); // Si clair → sombre
    } else {
      await setThemeMode(ThemeMode.light); // Si sombre → clair
    }
  }
}


/*
 * UTILISATION DES PROVIDERS :
 *
 * 1. Dans un widget, accéder au provider :
 *
 *    // Lecture seule (n'écoute pas les changements)
 *    final authProvider = context.read<AuthProvider>();
 *
 *    // Écoute les changements (rebuild quand notifyListeners())
 *    final authProvider = context.watch<AuthProvider>();
 *
 *    // Méthode alternative
 *    final authProvider = Provider.of<AuthProvider>(context);
 *
 * 2. Connexion :
 *    bool success = await authProvider.login(phone, password);
 *    if (success) {
 *      Navigator.pushReplacementNamed(context, '/dashboard');
 *    }
 *
 * 3. Changer le thème :
 *    final themeProvider = context.read<ThemeProvider>();
 *    await themeProvider.toggleTheme();
 */