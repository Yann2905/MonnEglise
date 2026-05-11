/*
 * FICHIER : lib/main.dart
 *
 * DESCRIPTION : Point d'entrée principal de l'application MonÉglise
 * Ce fichier initialise Supabase, configure les providers (gestionnaires d'état)
 * et définit toutes les routes de navigation de l'application
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart'; // ✅ Pour le calendrier en français
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'supabase_config.dart';

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_choice_screen.dart';
import 'screens/auth/register_admin_screen.dart';
import 'screens/auth/register_member_screen.dart';
import 'screens/auth/member_welcome_screen.dart';
import 'screens/auth/admin_welcome_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/member/member_dashboard.dart';

import 'providers/auth_provider.dart' as app_providers;
import 'providers/theme_provider.dart';
import 'core/app_theme.dart';
import 'core/cupertino_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialise les locales pour le calendrier en français
  // DOIT être appelé avant runApp
  await initializeDateFormatting('fr_FR', null);

  // ✅ Force l'orientation portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ✅ Style de la barre de statut (transparent)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );

  // ✅ Initialisation de Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_providers.AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title:                    'MonÉglise',
          debugShowCheckedModeBanner: false,

          // ✅ Thèmes Material (écrans pas encore migrés vers iOS)
          // + cupertinoOverrideTheme : les écrans Cupertino héritent du look iOS
          theme: AppTheme.lightTheme.copyWith(
            cupertinoOverrideTheme: IOSTheme.light,
          ),
          darkTheme: AppTheme.darkTheme.copyWith(
            cupertinoOverrideTheme: IOSTheme.dark,
          ),
          themeMode: themeProvider.themeMode,

          initialRoute: '/',

          routes: {
            '/':                  (context) => const SplashScreen(),
            '/login':             (context) => const LoginScreen(),
            '/register-choice':   (context) => const RegisterChoiceScreen(),
            '/register-admin':    (context) => const RegisterAdminScreen(),
            '/register-member':   (context) => const RegisterMemberScreen(),
            '/member-welcome':    (context) => const MemberWelcomeScreen(),
            '/admin-welcome':     (context) => const AdminWelcomeScreen(),
            '/admin-dashboard':   (context) => const AdminDashboard(),
            '/member-dashboard':  (context) => const MemberDashboard(),
          },
        );
      },
    );
  }
}