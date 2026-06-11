/*
 * FICHIER : lib/screens/admin/absence_detail_screen.dart
 *
 * REDESIGN "iOS" — Détail d'un appel d'absence :
 * — Carte résumé (famille + nb absents + date)
 * — Liste inset grouped des absents (nom + raison + bouton Appeler)
 */

import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/cupertino_theme.dart';
import '../../models/absence_model.dart';
import '../../widgets/user_avatar.dart';

class AbsenceDetailScreen extends StatefulWidget {
  final AbsenceModel absence;
  const AbsenceDetailScreen({super.key, required this.absence});

  @override
  State<AbsenceDetailScreen> createState() => _AbsenceDetailScreenState();
}

class _AbsenceDetailScreenState extends State<AbsenceDetailScreen> {
  final _supabase = Supabase.instance.client;
  // user_id → { 'first_name', 'last_name', 'avatar_url' }
  Map<String, Map<String, String?>> _userInfo = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAvatars());
  }

  Future<void> _loadAvatars() async {
    try {
      final ids = widget.absence.absentMembers
          .map((m) => m.userId)
          .where((id) => id.isNotEmpty)
          .toList();
      if (ids.isEmpty) return;
      final data = await _supabase
          .from('users')
          .select('id, first_name, last_name, avatar_url')
          .inFilter('id', ids);
      if (!mounted) return;
      setState(() {
        _userInfo = {
          for (final u in (data as List))
            (u as Map)['id'] as String: {
              'first_name': u['first_name'] as String?,
              'last_name': u['last_name'] as String?,
              'avatar_url': u['avatar_url'] as String?,
            }
        };
      });
    } catch (_) {
      // silencieux : fallback initiales
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// Extrait (firstName, lastName) depuis le nom complet — pour les anciennes
  /// absences où on n'a que `name`.
  (String, String) _splitName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return ('', '');
    if (parts.length == 1) return (parts[0], '');
    return (parts[0], parts.sublist(1).join(' '));
  }

  @override
  Widget build(BuildContext context) {
    final red = IOSTheme.systemRed(context);
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.absence.familyName,
            style: TextStyle(
              inherit: false,
              fontFamily: IOSTheme.fontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: IOSTheme.label(context),
            )),
        backgroundColor:
            IOSTheme.groupedBackground(context).withValues(alpha: 0.9),
      ),
      child: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // Résumé
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: IOSTheme.cardBackground(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(CupertinoIcons.calendar_badge_minus,
                        color: red, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.absence.familyName,
                            style: IOSTheme.body(context)
                                .copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.absence.absentCount} absent${widget.absence.absentCount > 1 ? "s" : ""} · ${widget.absence.date.day}/${widget.absence.date.month}/${widget.absence.date.year}',
                          style: IOSTheme.footnote(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('MEMBRES ABSENTS',
                  style: IOSTheme.sectionHeader(context)
                      .copyWith(fontSize: 12, letterSpacing: 0.6)),
            ),
            if (widget.absence.absentMembers.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: IOSTheme.cardBackground(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text('Aucun absent',
                      style: IOSTheme.body(context).copyWith(
                          color: IOSTheme.secondaryLabel(context))),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: IOSTheme.cardBackground(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children:
                      List.generate(widget.absence.absentMembers.length, (i) {
                    final m = widget.absence.absentMembers[i];
                    final isLast = i == widget.absence.absentMembers.length - 1;
                    // Données utilisateur enrichies (avatar / prénom / nom)
                    final info = _userInfo[m.userId];
                    final (firstNameFromSplit, lastNameFromSplit) =
                        _splitName(m.name);
                    final firstName =
                        info?['first_name'] ?? firstNameFromSplit;
                    final lastName = info?['last_name'] ?? lastNameFromSplit;
                    final avatarUrl = info?['avatar_url'];
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              UserAvatar(
                                firstName: firstName,
                                lastName: lastName,
                                avatarUrl: avatarUrl,
                                accentColor: red,
                                size: 36,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(m.name,
                                        style: IOSTheme.body(context)
                                            .copyWith(
                                                fontWeight:
                                                    FontWeight.w500)),
                                    if (m.reason != null &&
                                        m.reason!.isNotEmpty)
                                      Text(m.reason!,
                                          style: IOSTheme.footnote(context)),
                                  ],
                                ),
                              ),
                              if (m.phone.isNotEmpty)
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  onPressed: () => _call(m.phone),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: IOSTheme.systemGreen(context)
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Icon(CupertinoIcons.phone_fill,
                                        size: 16,
                                        color:
                                            IOSTheme.systemGreen(context)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Container(
                            margin: const EdgeInsets.only(left: 62),
                            height: 0.5,
                            color: IOSTheme.separator(context),
                          ),
                      ],
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
