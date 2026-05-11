/*
 * FICHIER : lib/screens/admin/services_screen.dart
 *
 * REDESIGN "iOS" — Cultes & événements (admin) :
 * — Liste des cultes (à venir + passés)
 * — Bouton + dans la nav bar → modal de création
 * — Modal : type (dimanche/midweek/special), titre, date+heure
 * — Long press sur un service → action sheet (Modifier / Supprimer)
 */

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/cupertino_theme.dart';
import '../../models/service_model.dart';
import '../../providers/auth_provider.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<ServiceModel> _upcoming = [];
  List<ServiceModel> _past = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user =
        Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    final churchId =
        user.churchId.isNotEmpty ? user.churchId : user.id;
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('services')
          .select()
          .eq('church_id', churchId)
          .order('date', ascending: true);
      if (!mounted) return;
      final all = (data as List)
          .map((e) =>
              ServiceModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final now = DateTime.now();
      setState(() {
        _upcoming = all.where((s) => s.date.isAfter(now)).toList();
        _past = all.reversed.where((s) => !s.date.isAfter(now)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCreateOrEdit({ServiceModel? existing}) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _ServiceFormSheet(
        existing: existing,
        onSaved: () async {
          Navigator.pop(ctx);
          await _load();
        },
      ),
    );
  }

  void _showActions(ServiceModel s) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(s.displayTitle),
        message: Text(_formatDate(s.date)),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _openCreateOrEdit(existing: s);
            },
            child: const Text('Modifier'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(s);
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

  void _confirmDelete(ServiceModel s) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Supprimer ce culte ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await _supabase.from('services').delete().eq('id', s.id);
              await _load();
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'janvier','février','mars','avril','mai','juin','juillet','août',
      'septembre','octobre','novembre','décembre'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year} · ${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Cultes & événements',
            style: TextStyle(
              inherit: false,
              fontFamily: IOSTheme.fontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: IOSTheme.label(context),
            )),
        backgroundColor:
            IOSTheme.groupedBackground(context).withValues(alpha: 0.9),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _openCreateOrEdit,
          child: Icon(CupertinoIcons.add_circled_solid,
              size: 28, color: blue),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : (_upcoming.isEmpty && _past.isEmpty)
                ? _empty(context)
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      if (_upcoming.isNotEmpty) ...[
                        _sectionHeader(context, 'À VENIR'),
                        const SizedBox(height: 8),
                        _list(_upcoming, future: true),
                      ],
                      if (_past.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _sectionHeader(context, 'PASSÉS'),
                        const SizedBox(height: 8),
                        _list(_past, future: false),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext ctx, String text) => Text(
        text,
        style: IOSTheme.sectionHeader(ctx)
            .copyWith(fontSize: 12, letterSpacing: 0.6),
      );

  Widget _list(List<ServiceModel> list, {required bool future}) {
    return Container(
      decoration: BoxDecoration(
        color: IOSTheme.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(list.length, (i) {
          final s = list[i];
          final isLast = i == list.length - 1;
          return Column(
            children: [
              GestureDetector(
                onLongPress: () => _showActions(s),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showActions(s),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        _typeIcon(s.type, future),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.displayTitle,
                                  style: IOSTheme.body(context)
                                      .copyWith(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 1),
                              Text(_formatDate(s.date),
                                  style: IOSTheme.footnote(context)),
                            ],
                          ),
                        ),
                        Icon(CupertinoIcons.chevron_right,
                            size: 14,
                            color: IOSTheme.tertiaryLabel(context)),
                      ],
                    ),
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
    );
  }

  Widget _typeIcon(String type, bool future) {
    final color = future
        ? IOSTheme.systemBlue(context)
        : IOSTheme.tertiaryLabel(context);
    final icon = type == 'special'
        ? CupertinoIcons.star_fill
        : type == 'midweek'
            ? CupertinoIcons.book_fill
            : CupertinoIcons.calendar;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _empty(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.calendar,
              size: 60, color: IOSTheme.tertiaryLabel(ctx)),
          const SizedBox(height: 16),
          Text('Aucun culte',
              style: IOSTheme.title2(ctx)
                  .copyWith(color: IOSTheme.secondaryLabel(ctx))),
          const SizedBox(height: 6),
          Text('Crée ton premier culte avec le bouton +',
              style: IOSTheme.subhead(ctx),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  MODAL CRÉATION / ÉDITION
// ══════════════════════════════════════════════

class _ServiceFormSheet extends StatefulWidget {
  final ServiceModel? existing;
  final VoidCallback onSaved;

  const _ServiceFormSheet({this.existing, required this.onSaved});

  @override
  State<_ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends State<_ServiceFormSheet> {
  final _supabase = Supabase.instance.client;
  late final TextEditingController _titleCtrl;
  late String _type;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.existing?.title ?? '');
    _type = widget.existing?.type ?? 'dimanche';
    _date = widget.existing?.date ??
        _nextSunday(DateTime.now().add(const Duration(hours: 9)));
  }

  DateTime _nextSunday(DateTime d) {
    final daysUntilSunday = (DateTime.sunday - d.weekday) % 7;
    return DateTime(d.year, d.month, d.day + daysUntilSunday, 9, 0);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user =
        Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    final churchId = user.churchId.isNotEmpty ? user.churchId : user.id;

    setState(() => _saving = true);
    try {
      final body = {
        'church_id': churchId,
        'type': _type,
        'title': _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        'date': _date.toIso8601String(),
        'created_by': user.id,
      };
      if (widget.existing == null) {
        await _supabase.from('services').insert(body);
      } else {
        await _supabase
            .from('services')
            .update(body)
            .eq('id', widget.existing!.id);
      }
      widget.onSaved();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);

    return Container(
      decoration: BoxDecoration(
        color: IOSTheme.cardBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        top: 8,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: IOSTheme.tertiaryLabel(context),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.existing == null ? 'Nouveau culte' : 'Modifier le culte',
            style: IOSTheme.title2(context),
          ),
          const SizedBox(height: 18),

          // Type
          CupertinoSlidingSegmentedControl<String>(
            groupValue: _type,
            onValueChanged: (v) => setState(() => _type = v ?? 'dimanche'),
            children: const {
              'dimanche': Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('Dimanche'),
              ),
              'midweek': Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('Semaine'),
              ),
              'special': Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('Spécial'),
              ),
            },
          ),
          const SizedBox(height: 18),

          // Titre
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: IOSTheme.tertiaryBackground(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CupertinoTextField(
              controller: _titleCtrl,
              placeholder: 'Titre (optionnel) — ex: Culte de Pâques',
              decoration: const BoxDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              prefix: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(CupertinoIcons.tag,
                    size: 18, color: IOSTheme.tertiaryLabel(context)),
              ),
              style: IOSTheme.body(context),
              placeholderStyle: IOSTheme.body(context).copyWith(
                color: IOSTheme.placeholder(context),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Date+heure inline picker
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: IOSTheme.tertiaryBackground(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.dateAndTime,
              use24hFormat: true,
              initialDateTime: _date,
              minimumDate:
                  DateTime.now().subtract(const Duration(days: 365)),
              maximumDate: DateTime.now().add(const Duration(days: 365 * 2)),
              onDateTimeChanged: (d) => _date = d,
            ),
          ),
          const SizedBox(height: 22),

          // Boutons
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: IOSTheme.tertiaryBackground(context),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(
                    'Annuler',
                    style: TextStyle(
                      inherit: false,
                      fontFamily: IOSTheme.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: IOSTheme.label(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoButton(
                  color: blue,
                  disabledColor: blue.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white)
                      : Text(
                          widget.existing == null ? 'Créer' : 'Enregistrer',
                          style: const TextStyle(
                            inherit: false,
                            fontFamily: IOSTheme.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
