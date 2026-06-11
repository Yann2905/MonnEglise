/*
 * FICHIER : lib/screens/splash_screen.dart
 *
 * REDESIGN "Terracotta" — Welcome Screen :
 * — Si user déjà connecté → redirect direct vers son dashboard
 * — Sinon → affiche un welcome plein terracotta animé avec :
 *     • Logo MonÉglise blanc centré
 *     • Titre "MonÉglise" + tagline
 *     • Bouton blanc plein "Créer un compte"
 *     • Bouton transparent bordé blanc "Se connecter"
 * — Arrière-plan animé : blobs flous qui flottent doucement
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/cupertino_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _checking = true;
  bool _shouldShowWelcome = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  Future<void> _checkSession() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Mode sans OTP : tente l'auto-login depuis SharedPreferences
    final restored = await auth.tryAutoLogin();
    if (!mounted) return;

    if (restored && auth.currentUser != null) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        auth.isAdmin ? '/admin-dashboard' : '/member-dashboard',
        (_) => false,
      );
    } else {
      setState(() {
        _checking = false;
        _shouldShowWelcome = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return CupertinoPageScaffold(
        backgroundColor: IOSTheme.systemBlueLight, // terracotta
        child: const Center(
          child: CupertinoActivityIndicator(
            color: CupertinoColors.white,
            radius: 14,
          ),
        ),
      );
    }
    if (!_shouldShowWelcome) {
      return const CupertinoPageScaffold(
        backgroundColor: CupertinoColors.white,
        child: SizedBox(),
      );
    }
    return _buildWelcome(context);
  }

  Widget _buildWelcome(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          // Fond terracotta animé
          Positioned.fill(
            child: AnimatedBlobBackground(
              baseColor: const Color(0xFF234A87), // bleu marine logo
              blobColors: const [
                Color(0xFF3D7CC9), // bleu clair
                Color(0xFF1A3866), // bleu marine foncé
                Color(0xFF5B8DD3), // bleu accent
              ],
            ),
          ),
          // Contenu
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Logo blanc
                  _buildLogo()
                      .animate()
                      .scale(
                        begin: const Offset(0.6, 0.6),
                        end: const Offset(1, 1),
                        duration: 700.ms,
                        curve: Curves.easeOutBack,
                      )
                      .fadeIn(duration: 500.ms),

                  const SizedBox(height: 18),

                  // Nom de l'app (Cormorant)
                  Text(
                    'MonÉglise',
                    style: TextStyle(
                      inherit: false,
                      fontFamily: IOSTheme.displayFontFamily,
                      fontSize: 44,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                      letterSpacing: 0.5,
                      decoration: TextDecoration.none,
                    ),
                  )
                      .animate(delay: 250.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(
                          begin: 0.2,
                          end: 0,
                          duration: 500.ms,
                          curve: Curves.easeOutCubic),

                  const SizedBox(height: 8),

                  // Tagline
                  Text(
                    'Votre communauté en un seul endroit',
                    style: TextStyle(
                      inherit: false,
                      fontFamily: IOSTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: CupertinoColors.white.withValues(alpha: 0.85),
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                  )
                      .animate(delay: 400.ms)
                      .fadeIn(duration: 500.ms),

                  const Spacer(flex: 4),

                  // Bouton "Créer un compte"
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      onPressed: () => Navigator.pushNamed(
                          context, '/register-choice'),
                      child: const Text(
                        'Créer un compte',
                        style: TextStyle(
                          inherit: false,
                          fontFamily: IOSTheme.fontFamily,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF234A87),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  )
                      .animate(delay: 600.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(
                          begin: 0.3,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOutCubic),

                  const SizedBox(height: 12),

                  // Bouton "Se connecter" (outlined)
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/login'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              CupertinoColors.white.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'Se connecter',
                          style: TextStyle(
                            inherit: false,
                            fontFamily: IOSTheme.fontFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: CupertinoColors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  )
                      .animate(delay: 750.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(
                          begin: 0.3,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOutCubic),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Logo MonÉglise — utilise le widget AppLogo qui zoom le PNG pour rogner les bords
  Widget _buildLogo() => const AppLogo(size: 130);
}
