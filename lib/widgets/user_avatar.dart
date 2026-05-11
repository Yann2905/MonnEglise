/*
 * FICHIER : lib/widgets/user_avatar.dart
 *
 * Widget réutilisable — Affiche la photo de profil OU les initiales
 * colorées en fallback. Utilisé dans toutes les listes (membres, familles,
 * notifications, profil, etc.).
 */

import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/cupertino_theme.dart';

class UserAvatar extends StatelessWidget {
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final double size;
  final Color? accentColor;

  const UserAvatar({
    super.key,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.size = 38,
    this.accentColor,
  });

  String get _initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return '$f$l'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? IOSTheme.systemBlue(context);
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    final radius = size / 2;
    final fontSize = size * 0.36;

    if (hasAvatar) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _initialsContainer(color, fontSize, radius),
          errorWidget: (_, __, ___) =>
              _initialsContainer(color, fontSize, radius),
        ),
      );
    }
    return _initialsContainer(color, fontSize, radius);
  }

  Widget _initialsContainer(Color color, double fontSize, double radius) {
    return Builder(
      builder: (context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(
              alpha: IOSTheme.isDark(context) ? 0.20 : 0.12),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Center(
          child: Text(
            _initials,
            style: TextStyle(
              inherit: false,
              fontFamily: IOSTheme.fontFamily,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
