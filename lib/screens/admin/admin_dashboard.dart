/*
 * FICHIER : lib/screens/admin/admin_dashboard.dart
 *
 * REDESIGN "Terracotta" — style card pastel (réf wellness) :
 * — Header : avatar + greeting + cloche notifs + profil
 * — Hero conditionnel :
 *     • Si dernier sermon a un audio  → carte sermon en hero (terracotta)
 *     • Sinon                         → carte familles en hero (sauge)
 * — Grille 2x2 pastel : Membres / Familles / Absences / Cultes
 * — Carte large "Notifications" en bas
 * — CupertinoTabBar inchangé pour les autres onglets
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/breakpoints.dart';
import '../../core/cupertino_theme.dart';
import '../../models/family_model.dart';
import '../../models/service_model.dart';
import '../../models/sermon_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/sermon_audio_hero.dart';
import '../../widgets/user_avatar.dart';
import '../shared/sermon_form_screen.dart';
import '../shared/sermons_screen.dart';
import 'attendance_screen.dart';
import 'families_screen.dart';
import 'members_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'services_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _db = DatabaseService();
  final _supabase = Supabase.instance.client;

  int _totalMembers = 0;
  int _totalFamilies = 0;
  int _absencesThisWeek = 0;
  int _unreadNotifications = 0;
  bool _loading = true;
  ServiceModel? _nextService;
  SermonModel? _latestSermon;
  List<FamilyModel> _families = [];

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final user =
          Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final id = user.id;
      final churchId =
          user.churchId.isNotEmpty ? user.churchId : id;

      final res = await Future.wait([
        _db.countMembers(id).catchError((_) => 0),
        _db.countFamilies(id).catchError((_) => 0),
        _countAbsencesThisWeek().catchError((_) => 0),
        _db.countUnreadNotifications(id).catchError((_) => 0),
      ]);

      ServiceModel? next;
      try {
        final nextRes = await _supabase
            .from('services')
            .select()
            .eq('church_id', churchId)
            .gte('date', DateTime.now().toIso8601String())
            .order('date', ascending: true)
            .limit(1)
            .maybeSingle();
        if (nextRes != null) {
          next = ServiceModel.fromJson(Map<String, dynamic>.from(nextRes));
        }
      } catch (_) {}

      SermonModel? latest;
      try {
        final s = await _supabase
            .from('sermons')
            .select()
            .eq('church_id', churchId)
            .order('sermon_date', ascending: false)
            .limit(1)
            .maybeSingle();
        if (s != null) {
          latest = SermonModel.fromJson(Map<String, dynamic>.from(s));
        }
      } catch (_) {}

      List<FamilyModel> fams = [];
      try {
        final f = await _supabase
            .from('families')
            .select()
            .eq('church_id', churchId)
            .order('name')
            .limit(3);
        fams = (f as List)
            .map((e) =>
                FamilyModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _totalMembers = res[0];
        _totalFamilies = res[1];
        _absencesThisWeek = res[2];
        _unreadNotifications = res[3];
        _nextService = next;
        _latestSermon = latest;
        _families = fams;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<int> _countAbsencesThisWeek() async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final absences = await _db.getAbsences(startDate: since);
    return absences.length;
  }

  // ══════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════

  void _switchTab(int i) => setState(() => _currentIndex = i);

  @override
  Widget build(BuildContext context) {
    final adminId =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? '';
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // ── Page courante (IndexedStack pour préserver le state) ──
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _HomeTab(
                    totalMembers: _totalMembers,
                    totalFamilies: _totalFamilies,
                    absencesThisWeek: _absencesThisWeek,
                    unreadNotifications: _unreadNotifications,
                    nextService: _nextService,
                    latestSermon: _latestSermon,
                    families: _families,
                    loading: _loading,
                    onRefresh: _loadAll,
                    onSwitchTab: _switchTab,
                  ),
                  const MembersScreen(),
                  const FamiliesScreen(),
                  const AttendanceScreen(),
                  NotificationsScreen(adminId: adminId),
                ],
              ),
            ),
            // ── Nav bar custom (pill bleu actif) ──
            AppBottomNav(
              currentIndex: _currentIndex,
              onTap: _switchTab,
              items: [
                const BottomNavItem(
                    icon: CupertinoIcons.house_fill, label: 'Accueil'),
                const BottomNavItem(
                    icon: CupertinoIcons.person_2_fill, label: 'Membres'),
                const BottomNavItem(
                    icon: CupertinoIcons.group_solid, label: 'Familles'),
                const BottomNavItem(
                    icon: CupertinoIcons.calendar, label: 'Absences'),
                BottomNavItem(
                  icon: CupertinoIcons.bell_fill,
                  label: 'Alertes',
                  badgeCount: _unreadNotifications > 0
                      ? _unreadNotifications
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  HOME TAB — style card pastel
// ══════════════════════════════════════════════

class _HomeTab extends StatelessWidget {
  final int totalMembers;
  final int totalFamilies;
  final int absencesThisWeek;
  final int unreadNotifications;
  final ServiceModel? nextService;
  final SermonModel? latestSermon;
  final List<FamilyModel> families;
  final bool loading;
  final Future<void> Function() onRefresh;
  final void Function(int) onSwitchTab;

  const _HomeTab({
    required this.totalMembers,
    required this.totalFamilies,
    required this.absencesThisWeek,
    required this.unreadNotifications,
    required this.nextService,
    required this.latestSermon,
    required this.families,
    required this.loading,
    required this.onRefresh,
    required this.onSwitchTab,
  });

  @override
  Widget build(BuildContext context) {
    final hasSermonAudio =
        latestSermon != null && latestSermon!.hasAudio;

    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: onRefresh),

            // Header
            SliverToBoxAdapter(child: _Header(onSwitchTab: onSwitchTab)),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── HERO : audio uniquement (rien sinon) ──
            if (hasSermonAudio) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: SermonAudioHero(
                    sermon: latestSermon!,
                    eyebrow: 'DERNIÈRE PRÉDICATION',
                    onListen: () =>
                        Navigator.of(context, rootNavigator: true)
                            .push(CupertinoPageRoute(
                                builder: (_) => const SermonsScreen())),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],

            // ── GRILLE PASTEL responsive (2 cols phone / 4 cols tablette+) ──
            SliverPadding(
              padding: EdgeInsets.symmetric(
                  horizontal: Breakpoints.horizontalPadding(context)),
              sliver: SliverToBoxAdapter(
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: Breakpoints.statGridColumns(context),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                  children: _buildCards(context),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // ── Carte "Ajouter une prédication" ──
            //   • Si pas de sermon audio        → bouton accent bleu "Ajouter"
            //   • Sinon (déjà un sermon)        → ligne discrète "+ Nouvelle prédication"
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _AddSermonCard(
                  hasSermon: hasSermonAudio,
                  onTap: () async {
                    final saved = await Navigator.of(context,
                            rootNavigator: true)
                        .push<bool>(CupertinoPageRoute(
                            builder: (_) => const SermonFormScreen()));
                    if (saved == true) await onRefresh();
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // ── Notifications ──
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _NotifCard(
                  unread: unreadNotifications,
                  onTap: () => onSwitchTab(4),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCards(BuildContext context) {
    final isDark = IOSTheme.isDark(context);

    Color soft(Color c) =>
        c.withValues(alpha: isDark ? 0.20 : 0.16);

    return [
      _PastelCard(
        bg: soft(IOSTheme.systemCoralLight),
        accent: IOSTheme.systemBlueLight, // terracotta
        icon: CupertinoIcons.person_2_fill,
        label: 'Membres',
        value: '$totalMembers',
        sub: 'Tap pour gérer',
        onTap: () => onSwitchTab(1),
        delayMs: 0,
      ),
      _PastelCard(
        bg: soft(IOSTheme.systemGreenLight),
        accent: IOSTheme.systemGreenLight,
        icon: CupertinoIcons.group_solid,
        label: 'Familles',
        value: '$totalFamilies',
        sub: 'Groupes & cellules',
        onTap: () => onSwitchTab(2),
        delayMs: 80,
      ),
      _PastelCard(
        bg: soft(IOSTheme.systemOrangeLight),
        accent: IOSTheme.systemOrangeLight,
        icon: CupertinoIcons.calendar_badge_minus,
        label: 'Absences',
        value: '$absencesThisWeek',
        sub: 'Cette semaine',
        onTap: () => onSwitchTab(3),
        delayMs: 160,
      ),
      _PastelCard(
        bg: soft(IOSTheme.systemTealLight),
        accent: IOSTheme.systemTealLight,
        icon: CupertinoIcons.calendar,
        label: 'Cultes',
        value: nextService != null ? '1' : '0',
        sub: nextService != null ? 'À venir' : 'À programmer',
        onTap: () => Navigator.of(context, rootNavigator: true)
            .push(CupertinoPageRoute(
                builder: (_) => const ServicesScreen())),
        delayMs: 240,
      ),
    ];
  }
}

// ══════════════════════════════════════════════
//  HEADER
// ══════════════════════════════════════════════
class _Header extends StatelessWidget {
  final void Function(int) onSwitchTab;
  const _Header({required this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        final user = auth.currentUser;
        final firstName = user?.firstName ?? '';
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              UserAvatar(
                firstName: firstName,
                lastName: user?.lastName ?? '',
                avatarUrl: user?.avatarUrl,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour,',
                      style: IOSTheme.footnote(context),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Pasteur $firstName 👋',
                      style: IOSTheme.body(context).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _CircleAction(
                icon: CupertinoIcons.bell,
                onTap: () => onSwitchTab(4),
              ),
              const SizedBox(width: 8),
              _CircleAction(
                icon: CupertinoIcons.person,
                onTap: () => Navigator.of(context, rootNavigator: true)
                    .push(CupertinoPageRoute(
                        builder: (_) => const ProfileScreen())),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: IOSTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: IOSTheme.label(context),
          size: 20,
        ),
      ),
    );
  }
}

// (Heroes _SermonHero et _FamiliesHero supprimés — remplacés par SermonAudioHero partagé.)

// ══════════════════════════════════════════════
//  CARTE PASTEL 2x2
// ══════════════════════════════════════════════
class _PastelCard extends StatelessWidget {
  final Color bg;
  final Color accent;
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final VoidCallback onTap;
  final int delayMs;

  const _PastelCard({
    required this.bg,
    required this.accent,
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.onTap,
    required this.delayMs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: CupertinoColors.white.withValues(
                        alpha: IOSTheme.isDark(context) ? 0.18 : 0.6),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 19, color: accent),
                ),
                Icon(
                  CupertinoIcons.arrow_up_right,
                  size: 16,
                  color: accent.withValues(alpha: 0.7),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    inherit: false,
                    fontFamily: IOSTheme.fontFamily,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: IOSTheme.label(context),
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: IOSTheme.body(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: IOSTheme.label(context),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  sub,
                  style: IOSTheme.caption(context).copyWith(
                    color: IOSTheme.label(context).withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: delayMs))
        .fadeIn(duration: 350.ms)
        .slideY(
            begin: 0.15,
            end: 0,
            duration: 400.ms,
            curve: Curves.easeOutCubic);
  }
}

// ══════════════════════════════════════════════
//  CARTE NOTIFICATIONS large
// ══════════════════════════════════════════════
class _NotifCard extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;
  const _NotifCard({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = IOSTheme.systemRed(context);
    final isDark = IOSTheme.isDark(context);
    final hasUnread = unread > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasUnread
              ? accent.withValues(alpha: isDark ? 0.20 : 0.14)
              : IOSTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CupertinoColors.white.withValues(
                    alpha: isDark ? 0.18 : 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                hasUnread
                    ? CupertinoIcons.bell_fill
                    : CupertinoIcons.bell,
                color: hasUnread ? accent : IOSTheme.tertiaryLabel(context),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasUnread ? 'Notifications' : 'Notifications',
                    style: IOSTheme.body(context)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasUnread
                        ? '$unread non lue${unread > 1 ? "s" : ""}'
                        : 'Tout est à jour',
                    style: IOSTheme.footnote(context),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
                size: 16, color: IOSTheme.tertiaryLabel(context)),
          ],
        ),
      ),
    )
        .animate(delay: 320.ms)
        .fadeIn(duration: 350.ms)
        .slideY(
            begin: 0.15,
            end: 0,
            duration: 400.ms,
            curve: Curves.easeOutCubic);
  }
}

// ══════════════════════════════════════════════
//  CARTE "Ajouter une prédication"
// ══════════════════════════════════════════════
class _AddSermonCard extends StatelessWidget {
  final bool hasSermon;
  final VoidCallback onTap;
  const _AddSermonCard({required this.hasSermon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    final isDark = IOSTheme.isDark(context);

    if (!hasSermon) {
      // Pas encore de sermon — gros call-to-action coloré
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: blue.withValues(alpha: isDark ? 0.20 : 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: blue.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: blue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  CupertinoIcons.add,
                  color: CupertinoColors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Partage une prédication',
                      style: IOSTheme.body(context).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Thème, versets et fichier audio',
                      style: IOSTheme.footnote(context),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_right,
                  size: 16, color: blue),
            ],
          ),
        ),
      );
    }

    // Déjà un sermon — ligne discrète secondaire
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: IOSTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: blue.withValues(alpha: isDark ? 0.20 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(CupertinoIcons.add, color: blue, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ajouter une prédication',
                style: IOSTheme.body(context)
                    .copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
                size: 14, color: IOSTheme.tertiaryLabel(context)),
          ],
        ),
      ),
    );
  }
}
