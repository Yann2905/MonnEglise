/*
 * FICHIER : lib/screens/admin/invite_screen.dart
 *
 * Écran d'invitation — partage l'église avec les futurs membres :
 * — QR code (lecture rapide depuis un appareil)
 * — Code à 6 caractères à dicter ou écrire
 * — Lien WhatsApp pré-rempli
 * — Bouton "Partager…" système
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/cupertino_theme.dart';
import '../../models/church_model.dart';
import '../../providers/auth_provider.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _supabase = Supabase.instance.client;
  ChurchModel? _church;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user =
        Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null || user.churchId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final res = await _supabase
          .from('churches')
          .select()
          .eq('id', user.churchId)
          .maybeSingle();
      if (!mounted) return;
      if (res != null) {
        setState(() {
          _church = ChurchModel.fromMap(Map<String, dynamic>.from(res));
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _shareMessage {
    if (_church == null) return '';
    final code = _church!.inviteCode ?? '—';
    return 'Rejoins l\'église ${_church!.name} sur MonÉglise.\n\n'
        'Télécharge l\'app, choisis "S\'inscrire" → "Membre", puis tape le code :\n\n'
        '$code';
  }

  Future<void> _copyCode() async {
    if (_church?.inviteCode == null) return;
    await Clipboard.setData(ClipboardData(text: _church!.inviteCode!));
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Copié !'),
        content: Text('Le code "${_church!.inviteCode}" a été copié.'),
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

  Future<void> _shareWhatsApp() async {
    final msg = Uri.encodeComponent(_shareMessage);
    final uri = Uri.parse('https://wa.me/?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareSystem() async {
    await Share.share(_shareMessage);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: IOSTheme.groupedBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Inviter des membres',
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
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _church == null
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        "Crée d'abord ton église pour pouvoir inviter des membres.",
                        style: IOSTheme.subhead(context),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    final code = _church!.inviteCode ?? '—';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // QR code
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: IOSTheme.cardBackground(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: code,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: CupertinoColors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(_church!.name,
                  style: IOSTheme.title2(context),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text("Présente ce QR aux nouveaux membres pour qu'ils rejoignent.",
                  style: IOSTheme.subhead(context),
                  textAlign: TextAlign.center),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // Code lisible
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text("CODE D'INVITATION",
              style: IOSTheme.sectionHeader(context)
                  .copyWith(fontSize: 12, letterSpacing: 0.6)),
        ),
        GestureDetector(
          onTap: _copyCode,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: IOSTheme.cardBackground(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    code,
                    style: TextStyle(
                      inherit: false,
                      fontFamily: IOSTheme.fontFamily,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: IOSTheme.label(context),
                      letterSpacing: 6,
                    ),
                  ),
                ),
                Icon(CupertinoIcons.doc_on_doc, color: blue, size: 22),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('Toucher pour copier dans le presse-papier',
              style: IOSTheme.caption(context)),
        ),

        const SizedBox(height: 22),

        // Boutons de partage
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('PARTAGER',
              style: IOSTheme.sectionHeader(context)
                  .copyWith(fontSize: 12, letterSpacing: 0.6)),
        ),
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                color: const Color(0xFF25D366), // WhatsApp green
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.symmetric(vertical: 17),
                onPressed: _shareWhatsApp,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(CupertinoIcons.chat_bubble_2_fill,
                        size: 18, color: CupertinoColors.white),
                    SizedBox(width: 8),
                    Text(
                      'WhatsApp',
                      style: TextStyle(
                        inherit: false,
                        fontFamily: IOSTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CupertinoButton(
                color: blue,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.symmetric(vertical: 17),
                onPressed: _shareSystem,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(CupertinoIcons.share,
                        size: 18, color: CupertinoColors.white),
                    SizedBox(width: 8),
                    Text(
                      'Partager…',
                      style: TextStyle(
                        inherit: false,
                        fontFamily: IOSTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
