/*
 * FICHIER : lib/screens/admin/members_screen.dart
 *
 * REDESIGN "iOS" — Liste Membres :
 * — CupertinoSearchTextField en haut
 * — Liste inset grouped iOS avec avatars colorés (initiales)
 * — Tap → action sheet : Appeler / Supprimer
 * — Pull-to-refresh natif
 * — Empty state iOS
 */

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/cupertino_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _adminId;
  bool _isLoading = true;
  List<UserModel> _members = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      _adminId = auth.currentUser?.id;
      _load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_adminId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('church_id', _adminId!)
          .order('first_name');
      if (!mounted) return;
      setState(() {
        _members = (data as List)
            .map((e) =>
                UserModel.fromSupabase(Map<String, dynamic>.from(e as Map)))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<UserModel> get _filtered {
    if (_searchQuery.isEmpty) return _members;
    final q = _searchQuery.toLowerCase();
    return _members
        .where((u) =>
            u.firstName.toLowerCase().contains(q) ||
            u.lastName.toLowerCase().contains(q) ||
            u.quartier.toLowerCase().contains(q) ||
            (u.role?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  Future<void> _callMember(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showActions(UserModel u) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(u.fullName),
        message: Text(u.phone),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _callMember(u.phone);
            },
            child: const Text('Appeler'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(u);
            },
            child: const Text('Supprimer'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
      ),
    );
  }

  void _confirmDelete(UserModel u) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Supprimer ce membre ?'),
        content: Text('${u.fullName} sera retiré de l\'église.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _supabase.from('users').delete().eq('id', u.id);
                if (!mounted) return;
                setState(() => _members.removeWhere((m) => m.id == u.id));
              } catch (_) {}
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
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
            largeTitle: const Text('Membres'),
            backgroundColor:
                IOSTheme.groupedBackground(context).withValues(alpha: 0.85),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            sliver: SliverToBoxAdapter(
              child: CupertinoSearchTextField(
                controller: _searchCtrl,
                placeholder: 'Nom, quartier, rôle…',
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: _load),
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                icon: CupertinoIcons.person_2,
                title: _searchQuery.isEmpty
                    ? 'Aucun membre'
                    : 'Aucun résultat',
                subtitle: _searchQuery.isEmpty
                    ? 'Aucun membre enregistré dans cette église.'
                    : 'Aucun membre ne correspond à "$_searchQuery".',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: IOSTheme.cardBackground(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: List.generate(_filtered.length, (i) {
                      final u = _filtered[i];
                      final isLast = i == _filtered.length - 1;
                      return Column(
                        children: [
                          _MemberRow(user: u, onTap: () => _showActions(u)),
                          if (!isLast)
                            Container(
                              margin: const EdgeInsets.only(left: 64),
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
//  MEMBER ROW
// ══════════════════════════════════════════════
class _MemberRow extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  const _MemberRow({required this.user, required this.onTap});

  Color _roleColor(BuildContext ctx) {
    switch (user.role) {
      case 'Pasteur secondaire':
        return IOSTheme.systemBlue(ctx);
      case 'Diacre':
      case 'Diaconesse':
        return IOSTheme.systemGreen(ctx);
      case 'Responsable':
        return IOSTheme.systemOrangeLight;
      default:
        return IOSTheme.systemBlue(ctx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            UserAvatar(
              firstName: user.firstName,
              lastName: user.lastName,
              avatarUrl: user.avatarUrl,
              size: 38,
              accentColor: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName,
                      style: IOSTheme.body(context)
                          .copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 1),
                  Text(
                    '${user.role ?? "Membre"} · ${user.quartier}',
                    style: IOSTheme.footnote(context),
                  ),
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
