/*
 * FICHIER : lib/screens/admin/profile_screen.dart
 *
 * REDESIGN "iOS" — Profil Admin :
 * — CupertinoNavigationBar avec back natif
 * — Avatar bleu translucide + initiales
 * — Listes inset grouped (téléphone, quartier, identifiant)
 * — Toggle Mode sombre via CupertinoSwitch
 * — Bouton Déconnecter rouge système
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../core/cupertino_theme.dart';
import '../../services/avatar_service.dart';
import '../../widgets/user_avatar.dart';
import '../auth/change_phone_screen.dart';
import 'invite_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Mon profil',
          style: TextStyle(
            inherit: false,
            fontFamily: IOSTheme.fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: IOSTheme.label(context),
            letterSpacing: -0.41,
          ),
        ),
        backgroundColor:
            IOSTheme.groupedBackground(context).withValues(alpha: 0.9),
        border: null,
      ),
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (_, auth, theme, __) {
          final user = auth.currentUser;
          if (user == null) {
            return const Center(child: CupertinoActivityIndicator());
          }
          final blue = IOSTheme.systemBlue(context);

          return SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _changeAvatar(context, auth),
                        child: Stack(
                          children: [
                            UserAvatar(
                              firstName: user.firstName,
                              lastName: user.lastName,
                              avatarUrl: user.avatarUrl,
                              size: 96,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: blue,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: IOSTheme.groupedBackground(context),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(CupertinoIcons.camera_fill,
                                    size: 14,
                                    color: CupertinoColors.white),
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .scale(
                            begin: const Offset(0.7, 0.7),
                            end: const Offset(1, 1),
                            duration: 450.ms,
                            curve: Curves.easeOutBack,
                          )
                          .fadeIn(duration: 350.ms),
                      const SizedBox(height: 14),
                      Text(user.fullName,
                              style: IOSTheme.title2(context))
                          .animate(delay: 100.ms)
                          .fadeIn(duration: 300.ms),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: blue.withValues(
                              alpha:
                                  IOSTheme.isDark(context) ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.shield_lefthalf_fill,
                                size: 12, color: blue),
                            const SizedBox(width: 4),
                            Text(
                              'Administrateur',
                              style: TextStyle(
                                inherit: false,
                                fontFamily: IOSTheme.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: blue,
                              ),
                            ),
                          ],
                        ),
                      ).animate(delay: 150.ms).fadeIn(duration: 300.ms),
                    ],
                  ),
                ),

                // ── Infos ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: Text(
                    'INFORMATIONS PERSONNELLES',
                    style: IOSTheme.sectionHeader(context)
                        .copyWith(fontSize: 12, letterSpacing: 0.6),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _GroupedList(
                    rows: [
                      _Row(CupertinoIcons.phone, 'Téléphone', user.phone,
                          onTap: () => Navigator.of(context,
                                  rootNavigator: true)
                              .push(CupertinoPageRoute(
                                  builder: (_) =>
                                      const ChangePhoneScreen()))),
                      _Row(CupertinoIcons.location, 'Quartier',
                          user.quartier),
                      _Row(
                        CupertinoIcons.creditcard,
                        'Code membre',
                        user.memberCode ?? '—',
                      ),
                    ],
                  ),
                ),

                // ── Paramètres ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
                  child: Text(
                    'PARAMÈTRES',
                    style: IOSTheme.sectionHeader(context)
                        .copyWith(fontSize: 12, letterSpacing: 0.6),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: IOSTheme.cardBackground(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              theme.isDarkMode
                                  ? CupertinoIcons.moon_fill
                                  : CupertinoIcons.sun_max_fill,
                              size: 16,
                              color: blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text('Mode sombre',
                                  style: IOSTheme.body(context))),
                          CupertinoSwitch(
                            value: theme.isDarkMode,
                            onChanged: (v) => theme.setThemeMode(
                              v ? ThemeMode.dark : ThemeMode.light,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Bouton Inviter ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: IOSTheme.cardBackground(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      onPressed: () => Navigator.of(context, rootNavigator: true)
                          .push(CupertinoPageRoute(
                              builder: (_) => const InviteScreen())),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: IOSTheme.systemGreen(context)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(CupertinoIcons.person_add_solid,
                                size: 15,
                                color: IOSTheme.systemGreen(context)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text('Inviter des membres',
                                  style: IOSTheme.body(context))),
                          Icon(CupertinoIcons.chevron_right,
                              size: 14,
                              color: IOSTheme.tertiaryLabel(context)),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Logout ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Container(
                    decoration: BoxDecoration(
                      color: IOSTheme.cardBackground(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      onPressed: () => _confirmLogout(context, auth),
                      child: Text(
                        'Se déconnecter',
                        style: TextStyle(
                          inherit: false,
                          fontFamily: IOSTheme.fontFamily,
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: IOSTheme.systemRed(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _changeAvatar(BuildContext context, AuthProvider auth) async {
    final user = auth.currentUser;
    if (user == null) return;

    final hasExisting = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;

    AvatarPickResult? choice;
    try {
      choice = await AvatarService.pickFromActionSheet(
        context,
        hasExisting: hasExisting,
      );
    } catch (_) {
      return;
    }
    if (choice == null) return; // annulé

    // → Suppression de la photo existante (avec confirmation)
    if (choice.action == AvatarPickAction.delete) {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Supprimer la photo ?'),
          content: const Text(
              'Voulez-vous vraiment supprimer votre photo de profil ? Les initiales seront affichées à la place.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final ok = await AvatarService.deleteAvatar(
        userId: user.id,
        publicId: user.avatarPublicId,
      );
      if (ok) {
        auth.updateLocalAvatarUrl('');
        await auth.refreshUser();
      } else if (context.mounted) {
        _showError(context, "Impossible de supprimer la photo.");
      }
      return;
    }

    // → Upload d'une nouvelle photo (l'ancienne sera nettoyée par le service)
    try {
      final url = await AvatarService.uploadAndSave(
        userId: user.id,
        xfile: choice.file!,
        oldPublicId: user.avatarPublicId,
      );
      if (url == null) {
        if (context.mounted) _showError(context, "Upload impossible.");
        return;
      }
      auth.updateLocalAvatarUrl(url);
      await auth.refreshUser();
    } catch (e) {
      if (context.mounted) _showError(context, 'UPLOAD: $e');
    }
  }

  void _showError(BuildContext context, String msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Debug avatar'),
        content: Text(msg),
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

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
            "Vous devrez vous reconnecter pour accéder à l'application."),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.logoutDirect();
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true)
                    .pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════

class _Row {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _Row(this.icon, this.label, this.value, {this.onTap});
}

class _GroupedList extends StatelessWidget {
  final List<_Row> rows;
  const _GroupedList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: IOSTheme.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(rows.length, (i) {
          final r = rows[i];
          final isLast = i == rows.length - 1;
          final cell = Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: IOSTheme.systemBlue(context)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(r.icon,
                      size: 15, color: IOSTheme.systemBlue(context)),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(r.label, style: IOSTheme.body(context))),
                Text(r.value,
                    style: IOSTheme.body(context).copyWith(
                        color: IOSTheme.secondaryLabel(context))),
                if (r.onTap != null) ...[
                  const SizedBox(width: 6),
                  Icon(CupertinoIcons.chevron_right,
                      size: 14,
                      color: IOSTheme.tertiaryLabel(context)),
                ],
              ],
            ),
          );
          return Column(
            children: [
              if (r.onTap != null)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: r.onTap,
                  child: cell,
                )
              else
                cell,
              if (!isLast)
                Container(
                  margin: const EdgeInsets.only(left: 54),
                  height: 0.5,
                  color: IOSTheme.separator(context),
                ),
            ],
          );
        }),
      ),
    );
  }
}
