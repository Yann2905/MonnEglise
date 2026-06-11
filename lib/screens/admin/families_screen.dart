/*
 * FICHIER : lib/screens/admin/families_screen.dart
 *
 * REDESIGN "iOS" — Familles Admin :
 * — Liste inset grouped des familles
 * — Bouton + dans la nav bar pour créer
 * — Tap sur une famille → écran de détail (liste des membres)
 * — Long press → action sheet (Renommer / Supprimer)
 */

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/cupertino_theme.dart';
import '../../models/family_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/user_avatar.dart';
import 'attendance_screen.dart';

class FamiliesScreen extends StatefulWidget {
  const FamiliesScreen({super.key});

  @override
  State<FamiliesScreen> createState() => _FamiliesScreenState();
}

class _FamiliesScreenState extends State<FamiliesScreen> {
  final _db = DatabaseService();
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<FamilyModel> _families = [];
  RealtimeChannel? _channel;

  /// Lit l'ID d'église à chaque appel (et non en cache) pour rester aligné
  /// avec le currentUser même après un re-seed ou un changement de session.
  String? get _currentChurchId {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return null;
    return user.churchId.isNotEmpty ? user.churchId : user.id;
  }

  String? get _currentUserId =>
      Provider.of<AuthProvider>(context, listen: false).currentUser?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _subscribe();
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  /// Realtime : reload à chaque modif de famille ou de family_members.
  /// Pas de filtre church_id sur family_members (le payload n'a pas cette info),
  /// donc on déclenche un reload conservateur.
  void _subscribe() {
    final churchId = _currentChurchId;
    if (churchId == null || churchId.isEmpty) return;
    _channel?.unsubscribe();
    _channel = _supabase
        .channel('admin_families_$churchId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'families',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'church_id',
            value: churchId,
          ),
          callback: (_) {
            if (mounted) _load();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'family_members',
          callback: (_) {
            if (mounted) _load();
          },
        )
        .subscribe();
  }

  Future<void> _load() async {
    final churchId = _currentChurchId;
    if (churchId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await _db.getFamilies(churchId);
      // ignore: avoid_print
      print('[FamiliesScreen] _load — church_id=$churchId, ${data.length} familles');
      if (!mounted) return;
      setState(() {
        _families = data
            .map((d) =>
                FamilyModel.fromSupabase(Map<String, dynamic>.from(d)))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('[FamiliesScreen] _load erreur: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════════════
  //  CRUD
  // ══════════════════════════════════════════════

  void _showCreateDialog() {
    final ctrl = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Nouvelle famille'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            placeholder: 'Ex: Jeunesse, Diaconat…',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;

              final churchId = _currentChurchId;
              final userId = _currentUserId;
              if (churchId == null || userId == null) {
                Navigator.pop(ctx);
                return;
              }

              Navigator.pop(ctx);
              final id = await _db.createFamily(
                name,
                churchId,
                responsibleId: userId,
              );
              // ignore: avoid_print
              print('[FamiliesScreen] createFamily('
                  'name=$name, church=$churchId, resp=$userId) → id=$id');
              if (id == null && mounted) {
                showCupertinoDialog(
                  context: context,
                  builder: (c) => CupertinoAlertDialog(
                    title: const Text('Création échouée'),
                    content: const Text(
                      'Impossible de créer la famille. Vérifie que ton église est bien créée.',
                    ),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
              await _load();
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _showFamilyActions(FamilyModel f) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(f.name),
        message: Text(
            '${f.memberCount} membre${f.memberCount > 1 ? "s" : ""}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showRenameDialog(f);
            },
            child: const Text('Renommer'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(f);
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

  void _showRenameDialog(FamilyModel f) {
    final ctrl = TextEditingController(text: f.name);
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Renommer la famille'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await _db.updateFamily(f.id, {'name': name});
              await _load();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(FamilyModel f) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Supprimer "${f.name}" ?'),
        content: const Text(
            'Voulez-vous vraiment supprimer cette famille ? Tous les membres en seront retirés. Cette action est irréversible.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await _db.deleteFamily(f.id);
              await _load();
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _openFamilyDetail(FamilyModel f) {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => FamilyDetailScreen(family: f, onUpdate: _load),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Familles'),
            backgroundColor:
                IOSTheme.groupedBackground(context).withValues(alpha: 0.85),
            transitionBetweenRoutes: false,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showCreateDialog,
              child: Icon(CupertinoIcons.add_circled_solid,
                  size: 28, color: blue),
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: _load),
          if (_isLoading)
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
                subtitle: 'Crée ta première famille avec le bouton +.',
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
                          _FamilyRow(
                            family: f,
                            onTap: () => _openFamilyDetail(f),
                            onLongPress: () => _showFamilyActions(f),
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
//  FAMILY ROW
// ══════════════════════════════════════════════
class _FamilyRow extends StatelessWidget {
  final FamilyModel family;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FamilyRow({
    required this.family,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final green = IOSTheme.systemGreen(context);
    // Le Comité a un look spécial : étoile dorée + badge "Officiel"
    final accent = family.isInstitutional
        ? IOSTheme.systemOrangeLight
        : green;
    final icon = family.isInstitutional
        ? CupertinoIcons.star_circle_fill
        : CupertinoIcons.group_solid;

    return GestureDetector(
      onLongPress: family.isInstitutional ? null : onLongPress,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(
                      alpha: IOSTheme.isDark(context) ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(family.name,
                              style: IOSTheme.body(context)
                                  .copyWith(fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (family.isInstitutional) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Officiel',
                              style: TextStyle(
                                inherit: false,
                                fontFamily: IOSTheme.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: accent,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${family.memberCount} membre${family.memberCount > 1 ? "s" : ""}',
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
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  ÉCRAN DÉTAIL FAMILLE
// ══════════════════════════════════════════════
class FamilyDetailScreen extends StatefulWidget {
  final FamilyModel family;
  final VoidCallback onUpdate;
  const FamilyDetailScreen(
      {super.key, required this.family, required this.onUpdate});

  @override
  State<FamilyDetailScreen> createState() => FamilyDetailScreenState();
}

class FamilyDetailScreenState extends State<FamilyDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<UserModel> _members = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Récupère les IDs des membres via la table de jointure
      final joinRes = await _supabase
          .from('family_members')
          .select('user_id')
          .eq('family_id', widget.family.id);
      final ids = (joinRes as List)
          .map((e) => (e as Map)['user_id'] as String)
          .toList();

      if (ids.isEmpty) {
        if (mounted) {
          setState(() {
            _members = [];
            _loading = false;
          });
        }
        return;
      }
      final data = await _supabase
          .from('users')
          .select()
          .inFilter('id', ids);
      if (!mounted) return;
      setState(() {
        _members = (data as List)
            .map((e) => UserModel.fromSupabase(
                Map<String, dynamic>.from(e as Map)))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Action sheet quand l'admin tape sur un membre de la famille.
  /// Propose : "Désigner comme responsable" (sauf si déjà) + "Retirer de la famille".
  void _showMemberActions(UserModel u, bool isResp) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(u.fullName),
        message: Text(AppConstants.labelOfChurchRole(u.churchRole)),
        actions: [
          if (!isResp && !widget.family.isInstitutional)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _setAsResponsible(u);
              },
              child: const Text('Désigner comme responsable'),
            ),
          if (isResp && !widget.family.isInstitutional)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                _removeResponsibleStatus(u);
              },
              child: const Text('Retirer du poste de responsable'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _removeMember(u);
            },
            child: const Text('Retirer de la famille'),
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

  /// Désigne `u` comme nouveau responsable de la famille.
  /// Le trigger SQL `sync_responsible_change` s'occupera de :
  ///   • Mettre church_role = responsable_famille pour u (donc l'ajouter au Comité)
  ///   • Démoter l'ancien responsable s'il n'est plus respo nulle part ailleurs
  Future<void> _setAsResponsible(UserModel u) async {
    try {
      await Supabase.instance.client
          .from('families')
          .update({'responsible_id': u.id})
          .eq('id', widget.family.id);
      // Mise à jour locale immédiate
      setState(() {
        // Ne change pas la liste mais l'UI se rafraîchira via Realtime
      });
      widget.onUpdate();
    } catch (e) {
      // ignore: avoid_print
      print('❌ _setAsResponsible: $e');
    }
  }

  /// Retire le statut de responsable (responsible_id devient NULL).
  /// Le trigger SQL démotera u en fidèle si plus respo ailleurs.
  Future<void> _removeResponsibleStatus(UserModel u) async {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Retirer ce responsable ?'),
        content: Text(
            "${u.fullName} ne sera plus responsable de cette famille. "
            "S'il n'est responsable d'aucune autre famille, il sera retiré du Comité."),
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
                await Supabase.instance.client
                    .from('families')
                    .update({'responsible_id': null})
                    .eq('id', widget.family.id);
                widget.onUpdate();
              } catch (_) {}
            },
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(UserModel u) async {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Retirer ${u.fullName} ?'),
        content: Text(
            'Voulez-vous vraiment retirer ${u.fullName} de la famille "${widget.family.name}" ?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseService().removeMemberFromFamily(
                  widget.family.id, u.id);
              await _load();
              widget.onUpdate();
            },
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddMembers() async {
    final added = await Navigator.of(context, rootNavigator: true).push<bool>(
      CupertinoPageRoute(
        builder: (_) => _AddMembersScreen(family: widget.family),
      ),
    );
    if (added == true) {
      await _load();
      widget.onUpdate();
    }
  }

  void _doAttendance() {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => AttendanceScreen(initialFamily: widget.family),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final me = auth.currentUser;
    final isAdmin = me?.roleGlobal == 'admin';
    final isResponsibleOfThis =
        me != null && widget.family.responsibleId == me.id;
    final canManage = isAdmin || isResponsibleOfThis;
    final blue = IOSTheme.systemBlue(context);

    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.family.name,
            style: TextStyle(
              inherit: false,
              fontFamily: IOSTheme.fontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: IOSTheme.label(context),
            )),
        backgroundColor:
            IOSTheme.groupedBackground(context).withValues(alpha: 0.9),
        trailing: canManage
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _openAddMembers,
                child: Icon(CupertinoIcons.person_add_solid,
                    color: blue, size: 24),
              )
            : null,
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  // ── Bouton "Faire l'appel" — CACHÉ pour le Comité
                  //    (la liste des responsables est un statut, pas un groupe
                  //     pour lequel on fait l'appel)
                  if (!widget.family.isInstitutional) ...[
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: blue,
                        borderRadius: BorderRadius.circular(14),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        onPressed: _members.isEmpty ? null : _doAttendance,
                        disabledColor: blue.withValues(alpha: 0.4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(CupertinoIcons.checkmark_seal_fill,
                                size: 18, color: CupertinoColors.white),
                            SizedBox(width: 8),
                            Text(
                              "Faire l'appel",
                              style: TextStyle(
                                inherit: false,
                                fontFamily: IOSTheme.fontFamily,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                  ] else ...[
                    // Bannière info pour le Comité
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: IOSTheme.systemOrangeLight.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.info_circle_fill,
                              color: IOSTheme.systemOrangeLight, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Liste officielle des responsables de l'église. La composition est gérée automatiquement selon le rôle de chaque membre.",
                              style: IOSTheme.footnote(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // ── Section "Membres" ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'MEMBRES (${_members.length})',
                      style: IOSTheme.sectionHeader(context)
                          .copyWith(fontSize: 12, letterSpacing: 0.6),
                    ),
                  ),

                  if (_members.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: IOSTheme.cardBackground(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text("Aucun membre dans cette famille.",
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
                        children: List.generate(_members.length, (i) {
                          final u = _members[i];
                          final isLast = i == _members.length - 1;
                          final isResp =
                              widget.family.responsibleId == u.id;
                          final roleLabel =
                              AppConstants.labelOfChurchRole(u.churchRole);
                          return Column(
                            children: [
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: canManage
                                    ? () => _showMemberActions(u, isResp)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      UserAvatar(
                                        firstName: u.firstName,
                                        lastName: u.lastName,
                                        avatarUrl: u.avatarUrl,
                                        size: 36,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(u.fullName,
                                                style: IOSTheme.body(context)
                                                    .copyWith(
                                                        fontWeight:
                                                            FontWeight.w500)),
                                            const SizedBox(height: 2),
                                            // Rôle d'église affiché en dessous
                                            // — orange + "Responsable" si c'est
                                            // le respo de CETTE famille
                                            if (isResp)
                                              Text(
                                                u.churchRole == AppConstants
                                                            .churchRoleResponsableFamille
                                                    ? 'Responsable'
                                                    : '$roleLabel · Responsable',
                                                style: IOSTheme.footnote(
                                                        context)
                                                    .copyWith(
                                                        color: IOSTheme
                                                            .systemOrangeLight,
                                                        fontWeight:
                                                            FontWeight.w600),
                                              )
                                            else
                                              Text(roleLabel,
                                                  style:
                                                      IOSTheme.footnote(context)),
                                          ],
                                        ),
                                      ),
                                      if (canManage)
                                        Icon(
                                          CupertinoIcons.chevron_right,
                                          size: 14,
                                          color:
                                              IOSTheme.tertiaryLabel(context),
                                        ),
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
                ],
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  ÉCRAN AJOUT MEMBRES À UNE FAMILLE
// ══════════════════════════════════════════════
class _AddMembersScreen extends StatefulWidget {
  final FamilyModel family;
  const _AddMembersScreen({required this.family});

  @override
  State<_AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<_AddMembersScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _loading = true;
  bool _saving = false;
  List<UserModel> _candidates = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Tous les users de la même église
      final users = await _supabase
          .from('users')
          .select()
          .eq('church_id', widget.family.churchId)
          .order('first_name');

      // Membres actuels de la famille (via la table de jointure)
      final currentMembers = await _supabase
          .from('family_members')
          .select('user_id')
          .eq('family_id', widget.family.id);
      final currentIds = (currentMembers as List)
          .map((e) => (e as Map)['user_id'] as String)
          .toSet();

      if (!mounted) return;
      setState(() {
        _candidates = (users as List)
            .map((e) => UserModel.fromSupabase(
                Map<String, dynamic>.from(e as Map)))
            .where((u) => !currentIds.contains(u.id))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<UserModel> get _filtered {
    if (_searchQuery.isEmpty) return _candidates;
    final q = _searchQuery.toLowerCase();
    return _candidates
        .where((u) =>
            u.firstName.toLowerCase().contains(q) ||
            u.lastName.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _save() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('family_members').upsert(
            _selected
                .map((uid) =>
                    {'family_id': widget.family.id, 'user_id': uid})
                .toList(),
            onConflict: 'family_id,user_id',
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Ajouter des membres',
            style: TextStyle(
              inherit: false,
              fontFamily: IOSTheme.fontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: IOSTheme.label(context),
            )),
        backgroundColor:
            IOSTheme.groupedBackground(context).withValues(alpha: 0.9),
        trailing: _selected.isEmpty
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CupertinoActivityIndicator()
                    : Text(
                        'Ajouter (${_selected.length})',
                        style: TextStyle(
                          inherit: false,
                          fontFamily: IOSTheme.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: blue,
                        ),
                      ),
              ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: CupertinoSearchTextField(
                controller: _searchCtrl,
                placeholder: 'Rechercher un membre…',
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? "Tous les membres de l'église sont déjà dans cette famille."
                                  : 'Aucun résultat.',
                              style: IOSTheme.subhead(context),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: IOSTheme.cardBackground(context),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children:
                                    List.generate(_filtered.length, (i) {
                                  final u = _filtered[i];
                                  final isLast = i == _filtered.length - 1;
                                  final selected = _selected.contains(u.id);
                                  return Column(
                                    children: [
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
                                          setState(() {
                                            if (selected) {
                                              _selected.remove(u.id);
                                            } else {
                                              _selected.add(u.id);
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                          child: Row(
                                            children: [
                                              UserAvatar(
                                                firstName: u.firstName,
                                                lastName: u.lastName,
                                                avatarUrl: u.avatarUrl,
                                                size: 36,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(u.fullName,
                                                        style: IOSTheme.body(
                                                                context)
                                                            .copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500)),
                                                    if (u.quartier.isNotEmpty)
                                                      Text(u.quartier,
                                                          style: IOSTheme
                                                              .footnote(context)),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: selected
                                                      ? blue
                                                      : CupertinoColors
                                                          .transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(11),
                                                  border: Border.all(
                                                    color: selected
                                                        ? blue
                                                        : IOSTheme
                                                            .tertiaryLabel(
                                                                context),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: selected
                                                    ? const Icon(
                                                        CupertinoIcons
                                                            .checkmark,
                                                        size: 14,
                                                        color: CupertinoColors
                                                            .white)
                                                    : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (!isLast)
                                        Container(
                                          margin: const EdgeInsets.only(
                                              left: 62),
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
