/*
 * FICHIER : lib/screens/shared/sermons_screen.dart
 *
 * Liste des prédications de l'église — partagée admin/membre.
 * — L'admin voit un bouton "+" dans la nav bar pour ajouter
 * — Tap sur un sermon → écran détail avec player audio
 * — Long press (admin) → action sheet : Modifier / Supprimer
 */

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/cupertino_theme.dart';
import '../../models/sermon_model.dart';
import '../../providers/auth_provider.dart';
import 'sermon_detail_screen.dart';
import 'sermon_form_screen.dart';

class SermonsScreen extends StatefulWidget {
  const SermonsScreen({super.key});

  @override
  State<SermonsScreen> createState() => _SermonsScreenState();
}

class _SermonsScreenState extends State<SermonsScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<SermonModel> _sermons = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user =
        Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    final churchId = user.churchId.isNotEmpty ? user.churchId : user.id;
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('sermons')
          .select()
          .eq('church_id', churchId)
          .order('sermon_date', ascending: false);
      if (!mounted) return;
      setState(() {
        _sermons = (data as List)
            .map((e) =>
                SermonModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({SermonModel? existing}) async {
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      CupertinoPageRoute(
        builder: (_) => SermonFormScreen(existing: existing),
      ),
    );
    if (saved == true) await _load();
  }

  void _openDetail(SermonModel s, {required bool isAdmin}) async {
    final result = await Navigator.of(context, rootNavigator: true).push<String>(
      CupertinoPageRoute(
        builder: (_) => SermonDetailScreen(sermon: s, isAdmin: isAdmin),
      ),
    );
    if (result == 'edit') {
      _openForm(existing: s);
    } else if (result == 'deleted') {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        final isAdmin = auth.currentUser?.roleGlobal == 'admin';
        return CupertinoPageScaffold(
          backgroundColor: IOSTheme.groupedBackground(context),
          navigationBar: CupertinoNavigationBar(
            middle: Text('Prédications',
                style: TextStyle(
                  inherit: false,
                  fontFamily: IOSTheme.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: IOSTheme.label(context),
                )),
            backgroundColor:
                IOSTheme.groupedBackground(context).withValues(alpha: 0.9),
            trailing: isAdmin
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _openForm(),
                    child: Icon(CupertinoIcons.add_circled_solid,
                        color: blue, size: 28),
                  )
                : null,
          ),
          child: SafeArea(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator())
                : _sermons.isEmpty
                    ? _empty(context, isAdmin)
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        itemCount: _sermons.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _SermonCard(
                          sermon: _sermons[i],
                          onTap: () =>
                              _openDetail(_sermons[i], isAdmin: isAdmin),
                        ),
                      ),
          ),
        );
      },
    );
  }

  Widget _empty(BuildContext ctx, bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.book,
              size: 60, color: IOSTheme.tertiaryLabel(ctx)),
          const SizedBox(height: 16),
          Text('Aucune prédication',
              style: IOSTheme.title2(ctx)
                  .copyWith(color: IOSTheme.secondaryLabel(ctx))),
          const SizedBox(height: 6),
          Text(
            isAdmin
                ? 'Touche le bouton + pour ajouter ta première prédication.'
                : 'Aucune prédication n\'a encore été partagée.',
            style: IOSTheme.subhead(ctx),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SermonCard extends StatelessWidget {
  final SermonModel sermon;
  final VoidCallback onTap;

  const _SermonCard({required this.sermon, required this.onTap});

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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: blue.withValues(alpha: isDark ? 0.20 : 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                sermon.hasAudio
                    ? CupertinoIcons.play_arrow_solid
                    : CupertinoIcons.book_fill,
                color: blue,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sermon.theme,
                    style: IOSTheme.body(context)
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(_format(sermon.sermonDate),
                          style: IOSTheme.footnote(context)),
                      if (sermon.formattedDuration != null) ...[
                        Text(' · ', style: IOSTheme.footnote(context)),
                        Icon(CupertinoIcons.clock,
                            size: 11,
                            color: IOSTheme.tertiaryLabel(context)),
                        const SizedBox(width: 2),
                        Text(sermon.formattedDuration!,
                            style: IOSTheme.footnote(context)),
                      ],
                    ],
                  ),
                  if (sermon.verses != null && sermon.verses!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      sermon.verses!,
                      style: IOSTheme.caption(context).copyWith(
                          color: IOSTheme.systemBlue(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
