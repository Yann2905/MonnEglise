/*
 * FICHIER : lib/screens/admin/attendance_screen.dart
 *
 * REDESIGN "iOS" — Module Absences (3 onglets) :
 * — Appel        : choisir famille + cocher absents + soumettre
 * — Historique   : appels passés
 * — Calendrier   : table_calendar style iOS
 *
 * Note : utilise le schéma `absences` avec colonne JSONB `absent_members`
 *        (cf. database/schema.sql).
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/cupertino_theme.dart';
import '../../core/constants.dart';
import '../../models/absence_model.dart';
import '../../models/family_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import 'absence_detail_screen.dart';

class AttendanceScreen extends StatefulWidget {
  /// Si fourni, l'écran lock sur cette famille (utilisé depuis détail famille).
  /// Sinon, l'utilisateur peut choisir parmi ses familles.
  final FamilyModel? initialFamily;

  const AttendanceScreen({super.key, this.initialFamily});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  int _segment = 0;
  final _supabase = Supabase.instance.client;
  final _db = DatabaseService();

  UserModel? _currentUser;
  List<FamilyModel> _myFamilies = [];
  FamilyModel? _selectedFamily;
  List<UserModel> _members = [];
  final Set<String> _absentIds = {};
  bool _loadingMembers = true;
  bool _submitting = false;

  // Historique
  bool _loadingHistory = false;
  List<Map<String, dynamic>> _history = [];

  // Calendrier
  bool _loadingCalendar = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _calendarEvents = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    _currentUser =
        Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (_currentUser == null) return;

    // Mode "famille verrouillée" : on vient du détail famille
    if (widget.initialFamily != null) {
      if (!mounted) return;
      setState(() => _myFamilies = [widget.initialFamily!]);
      await _selectFamily(widget.initialFamily!);
      return;
    }

    // Mode global : charge toutes les familles de l'église
    try {
      final churchId = _currentUser!.churchId.isNotEmpty
          ? _currentUser!.churchId
          : _currentUser!.id;
      final all = await _db.getFamilies(churchId);
      final families = all
          .map((d) =>
              FamilyModel.fromSupabase(Map<String, dynamic>.from(d)))
          .toList();
      if (!mounted) return;
      setState(() => _myFamilies = families);
      if (families.isNotEmpty) {
        await _selectFamily(families.first);
      } else {
        setState(() => _loadingMembers = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _selectFamily(FamilyModel f) async {
    setState(() {
      _selectedFamily = f;
      _loadingMembers = true;
      _absentIds.clear();
    });
    try {
      // Récupère les IDs membres via la table de jointure
      final memberIds = await _db.getMemberIdsForFamily(f.id);
      final members = <UserModel>[];
      for (final id in memberIds) {
        final d = await _db.getMember(id);
        if (d != null) {
          members.add(UserModel.fromSupabase(Map<String, dynamic>.from(d)));
        }
      }
      if (!mounted) return;
      setState(() {
        _members = members;
        _loadingMembers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedFamily == null || _currentUser == null) return;
    setState(() => _submitting = true);
    try {
      final absentList = _members
          .where((m) => _absentIds.contains(m.id))
          .map((m) => {
                'user_id': m.id,
                'name': m.fullName,
                'phone': m.phone,
              })
          .toList();
      // ── Service par défaut si aucun n'est créé pour aujourd'hui ──
      final today = DateTime.now();
      final dayStart = DateTime(today.year, today.month, today.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final churchId = _currentUser!.churchId.isNotEmpty
          ? _currentUser!.churchId
          : _currentUser!.id;

      String? serviceId;
      try {
        final existing = await _supabase
            .from('services')
            .select('id')
            .eq('church_id', churchId)
            .gte('date', dayStart.toIso8601String())
            .lt('date', dayEnd.toIso8601String())
            .maybeSingle();
        if (existing != null) {
          serviceId = existing['id'] as String?;
        } else {
          final created = await _supabase.from('services').insert({
            'church_id': churchId,
            'type': today.weekday == DateTime.sunday ? 'dimanche' : 'midweek',
            'title': 'Culte du ${today.day}/${today.month}/${today.year}',
            'date': today.toIso8601String(),
            'created_by': _currentUser!.id,
          }).select('id').single();
          serviceId = created['id'] as String?;
        }
      } catch (_) {
        // si la table services n'existe pas, on insère sans service_id
      }

      final actorName = _currentUser!.fullName;

      await _supabase.from('absences').insert({
        'family_id': _selectedFamily!.id,
        'family_name': _selectedFamily!.name,
        'date': today.toIso8601String(),
        'created_by': _currentUser!.id,
        'absent_count': absentList.length,
        'absent_members': absentList,
        if (serviceId != null) 'service_id': serviceId,
        'actor_name': actorName,
      });

      // ── Notif automatique au pasteur (admin de l'église) ─────────
      // Seulement si le user qui fait l'appel n'est PAS lui-même l'admin.
      try {
        final adminRes = await _supabase
            .from('users')
            .select('id')
            .eq('church_id', churchId)
            .eq('role_global', 'admin')
            .maybeSingle();
        final adminId = adminRes?['id'] as String?;
        if (adminId != null && adminId != _currentUser!.id) {
          await _supabase.from('notifications').insert({
            'title': 'Appel : ${_selectedFamily!.name}',
            'message':
                'Fait par $actorName · ${absentList.length} absent${absentList.length > 1 ? "s" : ""} sur ${_members.length}',
            'type': AppConstants.notificationTypeAbsence,
            'sender_id': _currentUser!.id,
            'receiver_id': adminId,
            'actor_name': actorName,
            'is_read': false,
          });
        }
      } catch (_) {
        // notif non critique
      }

      if (!mounted) return;
      _showAlert('Appel enregistré',
          '${absentList.length} absent${absentList.length > 1 ? "s" : ""} sur ${_members.length} membre${_members.length > 1 ? "s" : ""}.');
      setState(() => _absentIds.clear());
    } catch (e) {
      if (!mounted) return;
      _showAlert('Erreur', "Impossible d'enregistrer : $e");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _loadHistory() async {
    if (_currentUser == null) return;
    setState(() => _loadingHistory = true);
    try {
      final data = await _supabase
          .from('absences')
          .select()
          .order('date', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _history = List<Map<String, dynamic>>.from(data as List);
        _loadingHistory = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _loadCalendar() async {
    setState(() => _loadingCalendar = true);
    try {
      final since = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
      final data = await _db.getAbsences(startDate: since);
      final map = <DateTime, List<Map<String, dynamic>>>{};
      for (final a in data) {
        try {
          final dt = DateTime.parse(a['date'] as String);
          final key = DateTime(dt.year, dt.month, dt.day);
          map.putIfAbsent(key, () => []).add(a);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _calendarEvents = map;
        _loadingCalendar = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCalendar = false);
    }
  }

  void _showAlert(String title, String desc) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(desc),
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

  void _showFamilyPicker() {
    if (_myFamilies.isEmpty) return;
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Choisir une famille'),
        actions: _myFamilies
            .map((f) => CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _selectFamily(f);
                  },
                  child: Text(f.name),
                ))
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
      ),
    );
  }

  void _onSegmentChanged(int v) {
    setState(() => _segment = v);
    if (v == 1 && _history.isEmpty) _loadHistory();
    if (v == 2 && _calendarEvents.isEmpty) _loadCalendar();
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
            largeTitle: const Text('Absences'),
            backgroundColor:
                IOSTheme.groupedBackground(context).withValues(alpha: 0.85),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _segment,
                  onValueChanged: (v) => _onSegmentChanged(v ?? 0),
                  children: const {
                    0: Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('Appel')),
                    1: Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('Historique')),
                    2: Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('Calendrier')),
                  },
                ),
              ),
            ),
          ),
          if (_segment == 0) ..._appelSlivers()
          else if (_segment == 1) ..._historySlivers()
          else ..._calendarSlivers(),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  TAB APPEL
  // ══════════════════════════════════════════════

  List<Widget> _appelSlivers() {
    if (_myFamilies.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Empty(
            icon: CupertinoIcons.group,
            title: 'Aucune famille',
            subtitle:
                "Vous n'êtes responsable d'aucune famille pour le moment.",
          ),
        ),
      ];
    }

    return [
      // Sélecteur de famille
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(
          child: GestureDetector(
            onTap: _showFamilyPicker,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: IOSTheme.cardBackground(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.group_solid,
                      color: IOSTheme.systemGreen(context), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Famille',
                            style: IOSTheme.caption(context)),
                        const SizedBox(height: 2),
                        Text(_selectedFamily?.name ?? '—',
                            style: IOSTheme.body(context)
                                .copyWith(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_down,
                      size: 14,
                      color: IOSTheme.tertiaryLabel(context)),
                ],
              ),
            ),
          ),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 16)),

      // Liste membres
      if (_loadingMembers)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CupertinoActivityIndicator()),
          ),
        )
      else if (_members.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: _Empty(
              icon: CupertinoIcons.person_2,
              title: 'Aucun membre',
              subtitle: "Cette famille n'a aucun membre.",
            ),
          ),
        )
      else ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'COCHER LES ABSENTS',
              style: IOSTheme.sectionHeader(context)
                  .copyWith(fontSize: 12, letterSpacing: 0.6),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: IOSTheme.cardBackground(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: List.generate(_members.length, (i) {
                  final m = _members[i];
                  final isLast = i == _members.length - 1;
                  final selected = _absentIds.contains(m.id);
                  return Column(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            if (selected) {
                              _absentIds.remove(m.id);
                            } else {
                              _absentIds.add(m.id);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? IOSTheme.systemRed(context)
                                      : CupertinoColors.transparent,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: selected
                                        ? IOSTheme.systemRed(context)
                                        : IOSTheme.tertiaryLabel(context),
                                    width: 1.5,
                                  ),
                                ),
                                child: selected
                                    ? const Icon(CupertinoIcons.checkmark,
                                        size: 14,
                                        color: CupertinoColors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(m.fullName,
                                    style: IOSTheme.body(context)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          margin: const EdgeInsets.only(left: 48),
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
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          sliver: SliverToBoxAdapter(
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: IOSTheme.systemBlue(context),
                disabledColor:
                    IOSTheme.systemBlue(context).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.symmetric(vertical: 16),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const CupertinoActivityIndicator(
                        color: CupertinoColors.white)
                    : Text(
                        'Enregistrer (${_absentIds.length} absent${_absentIds.length > 1 ? "s" : ""})',
                        style: const TextStyle(
                          inherit: false,
                          fontFamily: IOSTheme.fontFamily,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    ];
  }

  // ══════════════════════════════════════════════
  //  TAB HISTORIQUE
  // ══════════════════════════════════════════════

  List<Widget> _historySlivers() {
    if (_loadingHistory) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CupertinoActivityIndicator()),
          ),
        ),
      ];
    }
    if (_history.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: _Empty(
              icon: CupertinoIcons.archivebox,
              title: 'Aucun historique',
              subtitle: "Aucun appel enregistré pour l'instant.",
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        sliver: SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              color: IOSTheme.cardBackground(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: List.generate(_history.length, (i) {
                final h = _history[i];
                final isLast = i == _history.length - 1;
                final date = DateTime.tryParse(h['date'] as String? ?? '') ??
                    DateTime.now();
                return Column(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        final model = AbsenceModel.fromMap(h);
                        Navigator.of(context, rootNavigator: true).push(
                          CupertinoPageRoute(
                            builder: (_) =>
                                AbsenceDetailScreen(absence: model),
                          ),
                        );
                      },
                      child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: IOSTheme.systemOrangeLight
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(CupertinoIcons.calendar,
                                color: IOSTheme.systemOrangeLight,
                                size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  h['family_name'] as String? ?? '—',
                                  style: IOSTheme.body(context)
                                      .copyWith(fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${date.day}/${date.month}/${date.year}',
                                  style: IOSTheme.footnote(context),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: IOSTheme.systemRed(context)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${h['absent_count'] ?? 0} abs',
                              style: TextStyle(
                                inherit: false,
                                fontFamily: IOSTheme.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: IOSTheme.systemRed(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(CupertinoIcons.chevron_right,
                              size: 14,
                              color: IOSTheme.tertiaryLabel(context)),
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
    ];
  }

  // ══════════════════════════════════════════════
  //  TAB CALENDRIER
  // ══════════════════════════════════════════════

  List<Widget> _calendarSlivers() {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        sliver: SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: IOSTheme.cardBackground(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: TableCalendar(
                focusedDay: _focusedDay,
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                selectedDayPredicate: (d) =>
                    _selectedDay != null && isSameDay(d, _selectedDay),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                onPageChanged: (focused) {
                  _focusedDay = focused;
                  _loadCalendar();
                },
                eventLoader: (day) {
                  final key = DateTime(day.year, day.month, day.day);
                  return _calendarEvents[key] ?? [];
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: IOSTheme.systemBlue(context)
                        .withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: IOSTheme.systemBlue(context),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: IOSTheme.systemRed(context),
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
              ),
            ),
          ),
        ),
      ),
      if (_loadingCalendar)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CupertinoActivityIndicator()),
          ),
        ),
    ];
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Empty(
      {required this.icon, required this.title, required this.subtitle});

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
