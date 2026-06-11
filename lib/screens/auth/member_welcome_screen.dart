/*
 * FICHIER : lib/screens/auth/member_welcome_screen.dart
 *
 * REDESIGN "Terracotta" — Bienvenue après inscription membre :
 * — Fond terracotta plein animé (blobs flous)
 * — Logo de l'église ou icône fallback (cercle blanc translucide)
 * — Cormorant : "Bienvenue" + "à l'église <nom>"
 * — Bouton blanc plein "Entrer"
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/cupertino_theme.dart';
import '../../models/church_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/permissions_modal.dart';

class MemberWelcomeScreen extends StatefulWidget {
  const MemberWelcomeScreen({super.key});

  @override
  State<MemberWelcomeScreen> createState() => _MemberWelcomeScreenState();
}

class _MemberWelcomeScreenState extends State<MemberWelcomeScreen> {
  final _supabase = Supabase.instance.client;
  ChurchModel? _church;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadChurch();
      if (!mounted) return;
      // Affiche le modal de demande de permissions juste après l'inscription
      await showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PermissionsModal(),
      );
    });
  }

  Future<void> _loadChurch() async {
    final user =
        Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null || user.churchId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final res = await _supabase
          .from('churches')
          .select()
          .eq('id', user.churchId)
          .maybeSingle();
      if (!mounted) return;
      if (res != null) {
        setState(() {
          _church = ChurchModel.fromMap(Map<String, dynamic>.from(res));
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          // Fond terracotta animé
          const Positioned.fill(
            child: AnimatedBlobBackground(
              baseColor: Color(0xFF234A87),
              blobColors: [
                Color(0xFF3D7CC9),
                Color(0xFF1A3866),
                Color(0xFF5B8DD3),
              ],
            ),
          ),

          // Contenu
          SafeArea(
            child: _loading
                ? const Center(
                    child: CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                      radius: 14,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Spacer(flex: 3),

                        // Logo de l'église si défini, sinon logo MonÉglise (rogné)
                        _church?.logoUrl != null &&
                                _church!.logoUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: Image.network(
                                  _church!.logoUrl!,
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const AppLogo(size: 140),
                                ),
                              )
                            : const AppLogo(size: 140)
                            .animate()
                            .scale(
                              begin: const Offset(0.6, 0.6),
                              end: const Offset(1, 1),
                              duration: 700.ms,
                              curve: Curves.easeOutBack,
                            )
                            .fadeIn(duration: 500.ms),

                        const SizedBox(height: 28),

                        // "Bienvenue"
                        Text(
                          'Bienvenue',
                          style: TextStyle(
                            fontFamily: IOSTheme.displayFontFamily,
                            fontSize: 44,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white,
                            letterSpacing: 0.3,
                          ),
                        )
                            .animate(delay: 250.ms)
                            .fadeIn(duration: 500.ms)
                            .slideY(
                                begin: 0.2,
                                end: 0,
                                duration: 500.ms,
                                curve: Curves.easeOutCubic),

                        const SizedBox(height: 6),

                        // "à l'église <nom>"
                        Text(
                          "à l'église ${_church?.name ?? "MonÉglise"}",
                          style: TextStyle(
                            inherit: false,
                            fontFamily: IOSTheme.fontFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            color: CupertinoColors.white
                                .withValues(alpha: 0.9),
                            letterSpacing: -0.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                            .animate(delay: 400.ms)
                            .fadeIn(duration: 500.ms),

                        const Spacer(flex: 4),

                        // Bouton "Entrer"
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton(
                            color: CupertinoColors.white,
                            borderRadius: BorderRadius.circular(16),
                            padding:
                                const EdgeInsets.symmetric(vertical: 17),
                            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                                context, '/member-dashboard', (_) => false),
                            child: const Text(
                              'Entrer',
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
                            .fadeIn(duration: 500.ms)
                            .slideY(
                                begin: 0.3,
                                end: 0,
                                duration: 500.ms,
                                curve: Curves.easeOutCubic),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
