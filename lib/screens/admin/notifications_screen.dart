/*
 * FICHIER : lib/screens/admin/notifications_screen.dart
 *
 * REDESIGN "iOS" — Notifications Admin :
 * — CupertinoSlidingSegmentedControl (Reçues / Envoyer)
 * — Tab 1 : liste reçues, swipe-to-delete iOS, pull-to-refresh
 * — Tab 2 : formulaire d'envoi (titre, message, destinataires)
 * — Alerts CupertinoAlertDialog natifs
 */

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/absence_model.dart';
import '../../models/notification_model.dart';
import '../../models/family_model.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';
import '../../core/cupertino_theme.dart';
import '../../core/helpers.dart';
import 'absence_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final String adminId;
  const NotificationsScreen({super.key, required this.adminId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _segment = 0;
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<NotificationModel> _received = [];
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadReceived();
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    if (widget.adminId.isEmpty) return;
    _channel?.unsubscribe();
    _channel = _supabase
        .channel('notifications_received_${widget.adminId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: widget.adminId,
          ),
          callback: (_) {
            if (mounted) _loadReceived();
          },
        )
        .subscribe();
  }

  Future<void> _loadReceived() async {
    if (widget.adminId.isEmpty) {
      // adminId pas encore disponible — on évite la requête qui ferait un 400
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('receiver_id', widget.adminId)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _received = (data as List)
            .map((e) => NotificationModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Gère le tap sur une notif — redirige selon son type/metadata
  Future<void> _handleNotifTap(NotificationModel n) async {
    // Type 'absence' → ouvre le détail de l'appel
    if (n.isAbsenceNotification) {
      final absenceId = n.metadata?['absence_id'] as String?;
      if (absenceId == null) return;
      try {
        final data = await _supabase
            .from('absences')
            .select()
            .eq('id', absenceId)
            .maybeSingle();
        if (data == null || !mounted) return;
        final model = AbsenceModel.fromMap(Map<String, dynamic>.from(data));
        Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(
            builder: (_) => AbsenceDetailScreen(absence: model),
          ),
        );
      } catch (_) {
        // notif corrompue ou absence supprimée → silencieux
      }
    }
    // (autres types : 'sermon', 'system', 'custom' → pas de redirection)
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true}).eq('id', id);
      _loadReceived();
    } catch (_) {}
  }

  Future<void> _delete(String id) async {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Supprimer cette notification ?'),
        content: const Text(
            'Voulez-vous vraiment supprimer cette notification ? Cette action est irréversible.'),
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
                await _supabase.from('notifications').delete().eq('id', id);
                _loadReceived();
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
    super.build(context);
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Alertes'),
            backgroundColor:
                IOSTheme.groupedBackground(context).withValues(alpha: 0.85),
            transitionBetweenRoutes: false,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _segment,
                  onValueChanged: (v) =>
                      setState(() => _segment = v ?? 0),
                  children: const {
                    0: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Reçues'),
                    ),
                    1: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Envoyer'),
                    ),
                  },
                ),
              ),
            ),
          ),
          if (_segment == 0) ..._receivedSlivers() else _sendSliver(),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── Tab 1 : Reçues ──
  List<Widget> _receivedSlivers() {
    if (_loading) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CupertinoActivityIndicator()),
        ),
      ];
    }
    if (_received.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(
            icon: CupertinoIcons.bell_slash,
            title: 'Aucune notification',
            subtitle: "Vous n'avez reçu aucune notification.",
          ),
        ),
      ];
    }
    return [
      CupertinoSliverRefreshControl(onRefresh: _loadReceived),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final n = _received[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NotifCard(
                  notif: n,
                  onTap: () {
                    if (!n.isRead) _markAsRead(n.id);
                    _handleNotifTap(n);
                  },
                  onDelete: () => _delete(n.id),
                ),
              );
            },
            childCount: _received.length,
          ),
        ),
      ),
    ];
  }

  Widget _sendSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _SendNotificationForm(
          adminId: widget.adminId,
          onSent: () {
            setState(() => _segment = 0);
            _loadReceived();
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  CARTE NOTIF
// ══════════════════════════════════════════════
class _NotifCard extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotifCard({
    required this.notif,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    final accent = notif.isAbsenceNotification
        ? IOSTheme.systemOrangeLight
        : blue;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
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
//  FORMULAIRE ENVOI
// ══════════════════════════════════════════════
class _SendNotificationForm extends StatefulWidget {
  final String adminId;
  final VoidCallback? onSent;

  const _SendNotificationForm({
    required this.adminId,
    this.onSent,
  });

  @override
  State<_SendNotificationForm> createState() => _SendNotificationFormState();
}

class _SendNotificationFormState extends State<_SendNotificationForm> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sendToAll = true; // par défaut : tous les membres
  final Set<String> _selectedFamilyIds = {};
  bool _isSending = false;
  List<FamilyModel> _families = [];
  final _supabase = Supabase.instance.client;

  String get _churchId =>
      Provider.of<AuthProvider>(context, listen: false).currentUser?.churchId ??
      '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFamilies());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFamilies() async {
    final churchId = _churchId;
    if (churchId.isEmpty) return;
    try {
      final res = await _supabase
          .from('v_families_enriched')
          .select()
          .eq('church_id', churchId)
          .order('name');
      if (!mounted) return;
      setState(() {
        _families = (res as List)
            .map((e) =>
                FamilyModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (title.isEmpty || message.isEmpty) {
      _alert('Champs requis', 'Le titre et le message sont obligatoires.');
      return;
    }
    if (!_sendToAll && _selectedFamilyIds.isEmpty) {
      _alert('Destinataire requis',
          'Sélectionnez "Tous les membres" ou au moins une famille.');
      return;
    }

    final churchId = _churchId;
    if (churchId.isEmpty) {
      _alert('Erreur', 'Église introuvable.');
      return;
    }

    setState(() => _isSending = true);
    try {
      // Collecte des destinataires (avec dédup)
      final Set<String> recipients = {};

      if (_sendToAll) {
        final res = await _supabase
            .from('users')
            .select('id')
            .eq('church_id', churchId);
        for (final u in (res as List)) {
          recipients.add(u['id'] as String);
        }
      } else {
        // Pour chaque famille sélectionnée → membres via family_members
        final res = await _supabase
            .from('family_members')
            .select('user_id')
            .inFilter('family_id', _selectedFamilyIds.toList());
        for (final r in (res as List)) {
          recipients.add(r['user_id'] as String);
        }
      }

      // On évite de s'envoyer à soi-même (admin expéditeur)
      recipients.remove(widget.adminId);

      if (recipients.isEmpty) {
        _alert('Aucun destinataire',
            'Les familles sélectionnées ne contiennent aucun membre.');
        setState(() => _isSending = false);
        return;
      }

      // Insertion en bulk (1 row par destinataire) — pour la liste in-app
      final rows = recipients
          .map((id) => {
                'title': title,
                'message': message,
                'type': AppConstants.notificationTypeCustom,
                'sender_id': widget.adminId,
                'receiver_id': id,
                'is_read': false,
              })
          .toList();
      await _supabase.from('notifications').insert(rows);

      // Push FCM via Edge Function (best-effort, ne bloque pas l'UX si KO)
      int pushSent = 0;
      try {
        final res = await _supabase.functions.invoke(
          'send-push',
          body: {
            'title': title,
            'message': message,
            'user_ids': recipients.toList(),
            'data': {'type': AppConstants.notificationTypeCustom},
          },
        );
        if (res.data is Map && res.data['sent'] is int) {
          pushSent = res.data['sent'] as int;
        }
      } catch (_) {
        // Edge Function indisponible → on a quand même les notifs in-app
      }

      if (!mounted) return;
      _titleCtrl.clear();
      _messageCtrl.clear();
      setState(() {
        _sendToAll = true;
        _selectedFamilyIds.clear();
      });
      widget.onSent?.call();
      _alert(
        'Notification envoyée',
        'Envoyée à ${recipients.length} membre${recipients.length > 1 ? 's' : ''}'
        '${pushSent > 0 ? ' (dont $pushSent en push)' : ''}.',
      );
    } catch (e) {
      _alert('Erreur', "Impossible d'envoyer : $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _alert(String title, String desc) {
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

  void _showRecipientPicker() {
    FocusScope.of(context).unfocus();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          // ↻ Le picker manipule directement notre state via setState parent,
          // mais on a aussi besoin de re-render le contenu de la sheet.
          void toggleAll() {
            setState(() {
              _sendToAll = true;
              _selectedFamilyIds.clear();
            });
            setLocal(() {});
          }

          void toggleFamily(String id) {
            setState(() {
              if (_selectedFamilyIds.contains(id)) {
                _selectedFamilyIds.remove(id);
                if (_selectedFamilyIds.isEmpty) _sendToAll = true;
              } else {
                _selectedFamilyIds.add(id);
                _sendToAll = false;
              }
            });
            setLocal(() {});
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.6,
            decoration: BoxDecoration(
              color: IOSTheme.cardBackground(ctx),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: IOSTheme.tertiaryLabel(ctx),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                    child: Row(
                      children: [
                        Text('Destinataires',
                            style: IOSTheme.title2(ctx).copyWith(fontSize: 20)),
                        const Spacer(),
                        CupertinoButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        _recipientCheckItem(
                          ctx,
                          icon: CupertinoIcons.person_3_fill,
                          label: 'Tous les membres',
                          checked: _sendToAll,
                          onTap: toggleAll,
                        ),
                        if (_families.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                            child: Text(
                              'FAMILLES',
                              style: IOSTheme.sectionHeader(ctx).copyWith(
                                fontSize: 12,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ..._families.map((f) => _recipientCheckItem(
                              ctx,
                              icon: CupertinoIcons.group_solid,
                              label: f.name,
                              checked: _selectedFamilyIds.contains(f.id),
                              onTap: () => toggleFamily(f.id),
                            )),
                        if (_families.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                            child: Text(
                              "Aucune famille créée pour le moment.",
                              style: IOSTheme.footnote(ctx),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _recipientCheckItem(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required bool checked,
    required VoidCallback onTap,
  }) {
    final blue = IOSTheme.systemBlue(ctx);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? blue : CupertinoColors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked ? blue : IOSTheme.tertiaryLabel(ctx),
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Icon(CupertinoIcons.checkmark,
                      size: 16, color: CupertinoColors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Icon(icon, color: blue, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: IOSTheme.body(ctx))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);

    String recipientLabel;
    IconData recipientIcon;
    if (_sendToAll) {
      recipientLabel = 'Tous les membres';
      recipientIcon = CupertinoIcons.person_3_fill;
    } else if (_selectedFamilyIds.isEmpty) {
      recipientLabel = 'Choisir des destinataires';
      recipientIcon = CupertinoIcons.person_crop_circle_badge_plus;
    } else if (_selectedFamilyIds.length == 1) {
      final f = _families.firstWhere(
        (f) => f.id == _selectedFamilyIds.first,
        orElse: () => FamilyModel(
          id: '',
          churchId: '',
          name: '—',
          responsibleId: '',
          createdAt: DateTime.now(),
        ),
      );
      recipientLabel = f.name;
      recipientIcon = CupertinoIcons.group_solid;
    } else {
      recipientLabel =
          '${_selectedFamilyIds.length} familles sélectionnées';
      recipientIcon = CupertinoIcons.group_solid;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Text(
          'TITRE',
          style: IOSTheme.sectionHeader(context)
              .copyWith(fontSize: 12, letterSpacing: 0.6),
        ),
        const SizedBox(height: 8),
        _iosField(
          controller: _titleCtrl,
          placeholder: 'Titre de la notification',
          icon: CupertinoIcons.bell_fill,
        ),
        const SizedBox(height: 18),
        Text(
          'MESSAGE',
          style: IOSTheme.sectionHeader(context)
              .copyWith(fontSize: 12, letterSpacing: 0.6),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: IOSTheme.tertiaryBackground(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CupertinoTextField(
            controller: _messageCtrl,
            placeholder: 'Tapez votre message…',
            maxLines: 5,
            decoration: const BoxDecoration(),
            padding: const EdgeInsets.all(14),
            style: IOSTheme.body(context),
            placeholderStyle: IOSTheme.body(context).copyWith(
              color: IOSTheme.placeholder(context),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'DESTINATAIRE',
          style: IOSTheme.sectionHeader(context)
              .copyWith(fontSize: 12, letterSpacing: 0.6),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showRecipientPicker,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: IOSTheme.tertiaryBackground(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  recipientIcon,
                  size: 18,
                  color: IOSTheme.tertiaryLabel(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(recipientLabel,
                        style: IOSTheme.body(context))),
                Icon(CupertinoIcons.chevron_down,
                    size: 14,
                    color: IOSTheme.tertiaryLabel(context)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: blue,
            disabledColor: blue.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.symmetric(vertical: 16),
            onPressed: _isSending ? null : _send,
            child: _isSending
                ? const CupertinoActivityIndicator(
                    color: CupertinoColors.white)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(CupertinoIcons.paperplane_fill,
                          size: 18, color: CupertinoColors.white),
                      SizedBox(width: 8),
                      Text(
                        'Envoyer',
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
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _iosField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: IOSTheme.tertiaryBackground(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        decoration: const BoxDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(icon,
              size: 18, color: IOSTheme.tertiaryLabel(context)),
        ),
        style: IOSTheme.body(context),
        placeholderStyle: IOSTheme.body(context).copyWith(
          color: IOSTheme.placeholder(context),
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
