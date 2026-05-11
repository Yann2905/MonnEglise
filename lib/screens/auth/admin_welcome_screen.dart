/*
 * FICHIER : lib/screens/auth/admin_welcome_screen.dart
 *
 * REDESIGN "Terracotta" — Bienvenue après création d'église :
 * — Fond terracotta plein animé (blobs)
 * — Logo de l'église (ou fallback)
 * — Cormorant : "Félicitations"
 * — Sous-titre avec le nom de l'église
 * — Carte avec le code d'invitation à partager
 * — Bouton "Entrer" → push admin-dashboard
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/cupertino_theme.dart';
import '../../models/church_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/app_logo.dart';

class AdminWelcomeScreen extends StatefulWidget {
  const AdminWelcomeScreen({super.key});

  @override
  State<AdminWelcomeScreen> createState() => _AdminWelcomeScreenState();
}

class _AdminWelcomeScreenState extends State<AdminWelcomeScreen> {
  final _supabase = Supabase.instance.client;
  ChurchModel? _church;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadChurch());
  }

  Future<void> _loadChurch() async {
    final user =
        Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final res = await _supabase
          .from('churches')
          .select()
          .eq('admin_id', user.id)
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

  /// Logo MonÉglise (PNG bien rogné) — fallback si pas de logo custom
  Widget _appLogoFallback() => const AppLogo(size: 120);

  Future<void> _copyCode() async {
    if (_church?.inviteCode == null) return;
    await Clipboard.setData(ClipboardData(text: _church!.inviteCode!));
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Copié'),
        content: Text(
            'Le code "${_church!.inviteCode}" est dans ton presse-papier.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        children: [
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
                        const Spacer(flex: 2),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: _church?.logoUrl != null &&
                                  _church!.logoUrl!.isNotEmpty
                              ? Image.network(
                                  _church!.logoUrl!,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _appLogoFallback(),
                                )
                              : _appLogoFallback(),
                        )
                            .animate()
                            .scale(
                              begin: const Offset(0.6, 0.6),
                              end: const Offset(1, 1),
                              duration: 700.ms,
                              curve: Curves.easeOutBack,
                            )
                            .fadeIn(duration: 500.ms),

                        const SizedBox(height: 24),

                        Text(
                          'Félicitations',
                          style: TextStyle(
                            fontFamily: IOSTheme.displayFontFamily,
                            fontSize: 40,
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

                        Text(
                          _church != null
                              ? 'Ton église ${_church!.name} est en place.'
                              : 'Ton église est en place.',
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
                        )
                            .animate(delay: 400.ms)
                            .fadeIn(duration: 500.ms),

                        const SizedBox(height: 28),

                        if (_church?.inviteCode != null) ...[
                          GestureDetector(
                            onTap: _copyCode,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: CupertinoColors.white
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: CupertinoColors.white
                                      .withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "CODE D'INVITATION",
                                        style: TextStyle(
                                          inherit: false,
                                          fontFamily: IOSTheme.fontFamily,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: CupertinoColors.white
                                              .withValues(alpha: 0.8),
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _church!.inviteCode!,
                                        style: TextStyle(
                                          inherit: false,
                                          fontFamily: IOSTheme.fontFamily,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          color: CupertinoColors.white,
                                          letterSpacing: 6,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  Icon(
                                    CupertinoIcons.doc_on_doc,
                                    color: CupertinoColors.white
                                        .withValues(alpha: 0.85),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          )
                              .animate(delay: 550.ms)
                              .fadeIn(duration: 500.ms)
                              .slideY(
                                  begin: 0.2,
                                  end: 0,
                                  duration: 500.ms,
                                  curve: Curves.easeOutCubic),
                          const SizedBox(height: 8),
                          Text(
                            'Partage ce code avec tes membres',
                            style: TextStyle(
                              inherit: false,
                              fontFamily: IOSTheme.fontFamily,
                              fontSize: 12,
                              color: CupertinoColors.white
                                  .withValues(alpha: 0.75),
                            ),
                          )
                              .animate(delay: 650.ms)
                              .fadeIn(duration: 400.ms),
                        ],

                        const Spacer(flex: 3),

                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton(
                            color: CupertinoColors.white,
                            borderRadius: BorderRadius.circular(16),
                            padding:
                                const EdgeInsets.symmetric(vertical: 17),
                            onPressed: () => Navigator.pushReplacementNamed(
                                context, '/admin-dashboard'),
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
                            .animate(delay: 750.ms)
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
