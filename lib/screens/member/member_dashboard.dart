/*
 * FICHIER : lib/screens/member/member_dashboard.dart
 *
 * REDESIGN "iOS" — Dashboard Membre :
 * — CupertinoTabScaffold avec 4 onglets : Accueil, Familles, Messages, Profil
 * — Chaque tab a une CupertinoSliverNavigationBar avec grand titre
 * — Pull-to-refresh iOS sur Accueil et Messages
 * — Listes en insetGrouped style (cellules iOS)
 * — Toggle thème via CupertinoSwitch
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../core/breakpoints.dart';
import '../../core/cupertino_theme.dart';
import '../../core/helpers.dart';
import '../../models/church_model.dart';
import '../../models/family_model.dart';
import '../../models/notification_model.dart';
import '../../models/service_model.dart';
import '../../models/sermon_model.dart';
import '../../services/avatar_service.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/sermon_audio_hero.dart';
import '../../widgets/user_avatar.dart';
import '../admin/families_screen.dart' show FamilyDetailScreen;
import '../auth/change_phone_screen.dart';
import '../shared/sermons_screen.dart';

class MemberDashboard extends StatefulWidget {
  const MemberDashboard({super.key});

  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends State<MemberDashboard> {
  final _supabase = Supabase.instance.client;
  int _currentIndex = 0;

  ChurchModel? _church;
  ServiceModel? _nextService;
  SermonModel? _latestSermon;
  List<FamilyModel> _myFamilies = [];
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChurchInfo();
      _loadNextService();
      _loadLatestSermon();
      _loadMyFamilies();
      _listenToUnreadNotifications();
    });
  }

  Future<void> _loadMyFamilies() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    try {
      final joinRes = await _supabase
          .from('family_members')
          .select('family_id')
          .eq('user_id', user.id);
      final ids = (joinRes as List)
          .map((e) => (e as Map)['family_id'] as String)
          .toList();
      if (ids.isEmpty) {
        if (mounted) setState(() => _myFamilies = []);
        return;
      }
      final data =
          await _supabase.from('families').select().inFilter('id', ids);
      if (!mounted) return;
      setState(() {
        _myFamilies = (data as List)
            .map((e) =>
                FamilyModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _loadLatestSermon() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null || user.churchId.isEmpty) return;
    try {
      final res = await _supabase
          .from('sermons')
          .select()
          .eq('church_id', user.churchId)
          .order('sermon_date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (!mounted || res == null) return;
      setState(() => _latestSermon =
          SermonModel.fromJson(Map<String, dynamic>.from(res)));
    } catch (_) {}
  }

  Future<void> _loadNextService() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null || user.churchId.isEmpty) return;
    try {
      final res = await _supabase
          .from('services')
          .select()
          .eq('church_id', user.churchId)
          .gte('date', DateTime.now().toIso8601String())
          .order('date', ascending: true)
          .limit(1)
          .maybeSingle();
      if (!mounted || res == null) return;
      setState(() => _nextService =
          ServiceModel.fromJson(Map<String, dynamic>.from(res)));
    } catch (_) {}
  }

  void _switchTab(int i) => setState(() => _currentIndex = i);

  Future<void> _loadChurchInfo() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    try {
      final res = await _supabase
          .from('churches')
          .select()
          .eq('id', user.churchId)
          .maybeSingle();
      if (res == null) return;
      if (mounted) {
        setState(() => _church = ChurchModel.fromMap(
              Map<String, dynamic>.from(res),
            ));
      }
    } catch (_) {}
  }

  void _listenToUnreadNotifications() {
    final uid =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    if (uid == null) return;
    _supabase.from('notifications').stream(primaryKey: ['id']).listen((data) {
      if (!mounted) return;
      final count = data
          .where((n) => n['receiver_id'] == uid && n['is_read'] == false)
          .length;
      setState(() => _unreadNotifications = count);
    });
  }

  // ══════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _HomeTab(
                    church: _church,
                    nextService: _nextService,
                    latestSermon: _latestSermon,
                    myFamilies: _myFamilies,
                    unreadCount: _unreadNotifications,
                    onSwitchTab: _switchTab,
                  ),
                  const _FamiliesTab(),
                  const _MessagesTab(),
                  const _ProfileTab(),
                ],
              ),
            ),
            AppBottomNav(
              currentIndex: _currentIndex,
              onTap: _switchTab,
              items: [
                const BottomNavItem(
                    icon: CupertinoIcons.house_fill, label: 'Accueil'),
                const BottomNavItem(
                    icon: CupertinoIcons.group_solid, label: 'Familles'),
                BottomNavItem(
                  icon: CupertinoIcons.chat_bubble_2_fill,
                  label: 'Messages',
                  badgeCount: _unreadNotifications > 0
                      ? _unreadNotifications
                      : null,
                ),
                const BottomNavItem(
                    icon: CupertinoIcons.person_fill, label: 'Profil'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _msgIcon(bool active) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(active
            ? CupertinoIcons.chat_bubble_2_fill
            : CupertinoIcons.chat_bubble_2),
        if (_unreadNotifications > 0)
          Positioned(
            right: -4,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              decoration: BoxDecoration(
                color: IOSTheme.systemRed(context),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                style: const TextStyle(
                  inherit: false,
                  fontFamily: IOSTheme.fontFamily,
                  color: CupertinoColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════
//  TAB 1 — ACCUEIL
// ══════════════════════════════════════════════

class _HomeTab extends StatelessWidget {
  final ChurchModel? church;
  final ServiceModel? nextService;
  final SermonModel? latestSermon;
  final List<FamilyModel> myFamilies;
  final int unreadCount;
  final void Function(int) onSwitchTab;
  const _HomeTab({
    required this.church,
    required this.nextService,
    required this.latestSermon,
    required this.myFamilies,
    required this.unreadCount,
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
            // Header
            SliverToBoxAdapter(child: _MemberHeader(church: church)),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),

            // ── HERO : audio uniquement (rien sinon) ──
            if (hasSermonAudio) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: SermonAudioHero(
                    sermon: latestSermon!,
                    eyebrow: 'NOUVELLE PRÉDICATION',
                    onListen: () =>
                        Navigator.of(context, rootNavigator: true)
                            .push(CupertinoPageRoute(
                                builder: (_) => const SermonsScreen())),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],

            // ── Grille pastel responsive ──
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

            // ── Carte profil rapide ──
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(child: _MiniProfileCard()),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCards(BuildContext context) {
    final isDark = IOSTheme.isDark(context);
    Color soft(Color c) => c.withValues(alpha: isDark ? 0.20 : 0.16);

    return [
      _MemberPastelCard(
        bg: soft(IOSTheme.systemGreenLight),
        accent: IOSTheme.systemGreenLight,
        icon: CupertinoIcons.group_solid,
        label: 'Familles',
        value: '${myFamilies.length}',
        sub: 'Mes groupes',
        onTap: () => onSwitchTab(1),
        delayMs: 0,
      ),
      _MemberPastelCard(
        bg: soft(IOSTheme.systemCoralLight),
        accent: IOSTheme.systemBlueLight,
        icon: CupertinoIcons.chat_bubble_2_fill,
        label: 'Messages',
        value: unreadCount > 0 ? '$unreadCount' : '0',
        sub: unreadCount > 0
            ? 'Non lu${unreadCount > 1 ? "s" : ""}'
            : 'À jour',
        onTap: () => onSwitchTab(2),
        delayMs: 80,
      ),
      _MemberPastelCard(
        bg: soft(IOSTheme.systemTealLight),
        accent: IOSTheme.systemTealLight,
        icon: CupertinoIcons.calendar,
        label: 'Prochain culte',
        value: nextService != null
            ? '${nextService!.date.day}/${nextService!.date.month}'
            : '—',
        sub: nextService != null ? nextService!.typeLabel : 'À venir',
        onTap: () {},
        delayMs: 160,
      ),
      _MemberPastelCard(
        bg: soft(IOSTheme.systemOrangeLight),
        accent: IOSTheme.systemOrangeLight,
        icon: CupertinoIcons.person_crop_circle_fill,
        label: 'Mon profil',
        value: '👤',
        sub: 'Voir & modifier',
        onTap: () => onSwitchTab(3),
        delayMs: 240,
      ),
    ];
  }
}

// ══════════════════════════════════════════════
//  Header membre (avatar + nom église)
// ══════════════════════════════════════════════
class _MemberHeader extends StatelessWidget {
  final ChurchModel? church;
  const _MemberHeader({required this.church});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        final user = auth.currentUser;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              UserAvatar(
                firstName: user?.firstName ?? '',
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
                      '${user?.firstName ?? ''} 👋',
                      style: IOSTheme.body(context).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (church?.name.isNotEmpty == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: IOSTheme.systemBlue(context)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.building_2_fill,
                          size: 11,
                          color: IOSTheme.systemBlue(context)),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(
                          church!.name,
                          style: TextStyle(
                            inherit: false,
                            fontFamily: IOSTheme.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: IOSTheme.systemBlue(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// (Anciennes classes _MemberSermonHero et _MemberFamiliesHero supprimées
//  — remplacées par le widget partagé SermonAudioHero.)

// ══════════════════════════════════════════════
//  CARTE PASTEL membre 2x2
// ══════════════════════════════════════════════
class _MemberPastelCard extends StatelessWidget {
  final Color bg;
  final Color accent;
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final VoidCallback onTap;
  final int delayMs;

  const _MemberPastelCard({
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
                    fontSize: 28,
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
        .slideY(begin: 0.15, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}

class _ChurchCard extends StatelessWidget {
  final ChurchModel church;
  const _ChurchCard({required this.church});

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: IOSTheme.cardBackground(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: blue.withValues(
                  alpha: IOSTheme.isDark(context) ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: church.logoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(church.logoUrl!, fit: BoxFit.cover),
                  )
                : Icon(CupertinoIcons.building_2_fill,
                    size: 26, color: blue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(church.name,
                    style: IOSTheme.body(context)
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Assemblée locale',
                    style: IOSTheme.footnote(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextServiceMemberCard extends StatelessWidget {
  final ServiceModel service;
  const _NextServiceMemberCard({required this.service});

  String _format(DateTime d) {
    const days = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
    const months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]} · ${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    final isDark = IOSTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.all(14),
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
              color: blue.withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              service.type == 'special'
                  ? CupertinoIcons.star_fill
                  : service.type == 'midweek'
                      ? CupertinoIcons.book_fill
                      : CupertinoIcons.calendar,
              color: blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.displayTitle,
                    style: IOSTheme.body(context)
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_format(service.date),
                    style: IOSTheme.footnote(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestSermonMemberCard extends StatelessWidget {
  final SermonModel sermon;
  final VoidCallback onTap;
  const _LatestSermonMemberCard({
    required this.sermon,
    required this.onTap,
  });

  String _format(DateTime d) {
    const months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    final isDark = IOSTheme.isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
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
                color: blue.withValues(alpha: isDark ? 0.20 : 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                sermon.hasAudio
                    ? CupertinoIcons.play_arrow_solid
                    : CupertinoIcons.book_fill,
                color: blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sermon.theme,
                      style: IOSTheme.body(context)
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(_format(sermon.sermonDate),
                      style: IOSTheme.footnote(context)),
                ],
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

class _MiniProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        final user = auth.currentUser;
        if (user == null) return const SizedBox();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: IOSTheme.cardBackground(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              UserAvatar(
                firstName: user.firstName,
                lastName: user.lastName,
                avatarUrl: user.avatarUrl,
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName,
                        style: IOSTheme.body(context)
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(user.role ?? 'Membre',
                        style: IOSTheme.footnote(context)),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_right,
                  size: 14, color: IOSTheme.tertiaryLabel(context)),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════
//  TAB 2 — FAMILLES
// ══════════════════════════════════════════════

class _FamiliesTab extends StatefulWidget {
  const _FamiliesTab();
  @override
  State<_FamiliesTab> createState() => _FamiliesTabState();
}

class _FamiliesTabState extends State<_FamiliesTab> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<FamilyModel> _families = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      // Récupère les familles via la table de jointure family_members
      final joinRes = await _supabase
          .from('family_members')
          .select('family_id')
          .eq('user_id', user.id);
      final familyIds = (joinRes as List)
          .map((e) => (e as Map)['family_id'] as String)
          .toList();

      if (familyIds.isEmpty) {
        if (mounted) {
          setState(() {
            _families = [];
            _loading = false;
          });
        }
        return;
      }

      final data = await _supabase
          .from('families')
          .select()
          .inFilter('id', familyIds);
      if (!mounted) return;
      setState(() {
        _families = (data as List)
            .map((e) =>
                FamilyModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Familles'),
            backgroundColor: IOSTheme.groupedBackground(context)
                .withValues(alpha: 0.85),
          ),
          CupertinoSliverRefreshControl(onRefresh: _load),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_families.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                icon: CupertinoIcons.group,
                title: 'Aucune famille',
                subtitle: "Vous n'êtes membre d'aucune famille pour le moment.",
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: IOSTheme.cardBackground(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: List.generate(_families.length, (i) {
                      final f = _families[i];
                      final isLast = i == _families.length - 1;
                      return Column(
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.of(context,
                                    rootNavigator: true)
                                .push(CupertinoPageRoute(
                                    builder: (_) => FamilyDetailScreen(
                                          family: f,
                                          onUpdate: _load,
                                        ))),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: IOSTheme.systemGreen(context)
                                          .withValues(
                                              alpha: IOSTheme.isDark(context)
                                                  ? 0.20
                                                  : 0.12),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.group_solid,
                                      size: 18,
                                      color: IOSTheme.systemGreen(context),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(f.name,
                                            style: IOSTheme.body(context)
                                                .copyWith(
                                                    fontWeight:
                                                        FontWeight.w500)),
                                        const SizedBox(height: 1),
                                        Text(
                                            '${f.memberCount} membre${f.memberCount > 1 ? "s" : ""}',
                                            style:
                                                IOSTheme.footnote(context)),
                                      ],
                                    ),
                                  ),
                                  Icon(CupertinoIcons.chevron_right,
                                      size: 14,
                                      color:
                                          IOSTheme.tertiaryLabel(context)),
                                ],
                              ),
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
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  TAB 3 — MESSAGES
// ══════════════════════════════════════════════

class _MessagesTab extends StatefulWidget {
  const _MessagesTab();
  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<NotificationModel> _notifs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final uid =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('receiver_id', uid)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _notifs = (data as List)
            .map((e) => NotificationModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead(String notifId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true}).eq('id', notifId);
      // Mise à jour locale immédiate (optimistic)
      setState(() {
        final idx = _notifs.indexWhere((n) => n.id == notifId);
        if (idx >= 0) _notifs[idx] = _notifs[idx].markAsRead();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Messages'),
            backgroundColor: IOSTheme.groupedBackground(context)
                .withValues(alpha: 0.85),
          ),
          CupertinoSliverRefreshControl(onRefresh: _load),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_notifs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                icon: CupertinoIcons.chat_bubble_2,
                title: 'Aucun message',
                subtitle: "Vous n'avez aucun message pour le moment.",
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final n = _notifs[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NotifCard(
                        notif: n,
                        onTap: () => _markAsRead(n.id),
                      ),
                    );
                  },
                  childCount: _notifs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    final accent = notif.isAbsenceNotification
        ? IOSTheme.systemOrangeLight
        : blue;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: IOSTheme.cardBackground(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(
                  alpha: IOSTheme.isDark(context) ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              notif.isAbsenceNotification
                  ? CupertinoIcons.calendar_badge_minus
                  : CupertinoIcons.bell_fill,
              size: 18,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        style: IOSTheme.body(context)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (!notif.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(notif.message, style: IOSTheme.footnote(context)),
                const SizedBox(height: 6),
                Text(Helpers.formatDateShort(notif.createdAt),
                    style: IOSTheme.caption(context)),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  TAB 4 — PROFIL
// ══════════════════════════════════════════════

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (_, auth, theme, __) {
          final user = auth.currentUser;
          if (user == null) {
            return const Center(child: CupertinoActivityIndicator());
          }
          final blue = IOSTheme.systemBlue(context);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text('Profil'),
                backgroundColor: IOSTheme.groupedBackground(context)
                    .withValues(alpha: 0.85),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                              size: 92,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: blue,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: IOSTheme.groupedBackground(context),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(CupertinoIcons.camera_fill,
                                    size: 13,
                                    color: CupertinoColors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(user.fullName, style: IOSTheme.title2(context)),
                      const SizedBox(height: 2),
                      Text(user.role ?? 'Membre',
                          style: IOSTheme.subhead(context)),
                    ],
                  ),
                ),
              ),

              // Section infos
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                sliver: SliverToBoxAdapter(
                  child: Text('INFORMATIONS',
                      style: IOSTheme.sectionHeader(context)
                          .copyWith(fontSize: 12, letterSpacing: 0.6)),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _GroupedList(rows: [
                    _Row(
                      CupertinoIcons.phone,
                      'Téléphone',
                      user.phone,
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .push(CupertinoPageRoute(
                              builder: (_) => const ChangePhoneScreen())),
                    ),
                    _Row(CupertinoIcons.location, 'Quartier', user.quartier),
                  ]),
                ),
              ),

              // Section paramètres
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
                sliver: SliverToBoxAdapter(
                  child: Text('PARAMÈTRES',
                      style: IOSTheme.sectionHeader(context)
                          .copyWith(fontSize: 12, letterSpacing: 0.6)),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
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
                              color: IOSTheme.systemBlue(context)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              theme.isDarkMode
                                  ? CupertinoIcons.moon_fill
                                  : CupertinoIcons.sun_max_fill,
                              size: 16,
                              color: IOSTheme.systemBlue(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Mode sombre',
                                style: IOSTheme.body(context)),
                          ),
                          CupertinoSwitch(
                            value: theme.isDarkMode,
                            onChanged: (v) => theme.setThemeMode(
                                v ? ThemeMode.dark : ThemeMode.light),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Logout
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                sliver: SliverToBoxAdapter(
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
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changeAvatar(BuildContext context, AuthProvider auth) async {
    final user = auth.currentUser;
    if (user == null) return;
    final file = await AvatarService.pickFromActionSheet(context);
    if (file == null) return;
    final url =
        await AvatarService.uploadAndSave(userId: user.id, xfile: file);
    if (url != null) {
      await auth.refreshUser();
    }
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
              await auth.logout();
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
                  child: Text(r.label, style: IOSTheme.body(context)),
                ),
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: IOSTheme.tertiaryLabel(context)),
          const SizedBox(height: 16),
          Text(title,
              style: IOSTheme.title2(context)
                  .copyWith(color: IOSTheme.secondaryLabel(context))),
          const SizedBox(height: 6),
          Text(subtitle,
              style: IOSTheme.subhead(context),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
