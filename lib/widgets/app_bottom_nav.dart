/*
 * FICHIER : lib/widgets/app_bottom_nav.dart
 *
 * Bottom nav custom — style "pill" :
 *  • Item actif    : badge bleu plein arrondi, icône + label blancs
 *  • Item inactif  : icône grise, label gris en dessous
 *  • Fond blanc avec ombre douce, coins arrondis
 *  • Animation au switch (AnimatedContainer)
 *
 * Usage :
 *   AppBottomNav(
 *     currentIndex: _index,
 *     onTap: (i) => setState(() => _index = i),
 *     items: [
 *       BottomNavItem(icon: CupertinoIcons.house_fill, label: 'Accueil'),
 *       ...
 *     ],
 *   )
 */

import 'package:flutter/cupertino.dart';
import '../core/cupertino_theme.dart';

class BottomNavItem {
  final IconData icon;
  final String label;
  /// Optionnel — petit badge rouge avec compteur (pour notifs non lues)
  final int? badgeCount;

  const BottomNavItem({
    required this.icon,
    required this.label,
    this.badgeCount,
  });
}

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItem> items;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = IOSTheme.isDark(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: Container(
          decoration: BoxDecoration(
            color: IOSTheme.cardBackground(context),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withValues(
                    alpha: isDark ? 0.30 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: IOSTheme.separator(context).withValues(alpha: 0.6),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(items.length, (i) {
              return Expanded(
                child: _NavItem(
                  item: items[i],
                  active: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final BottomNavItem item;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final blue = IOSTheme.systemBlue(context);
    final inactive = IOSTheme.tertiaryLabel(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? blue : CupertinoColors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                item.icon,
                size: 22,
                color: active ? CupertinoColors.white : inactive,
              ),
              if (item.badgeCount != null && item.badgeCount! > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    decoration: BoxDecoration(
                      color: IOSTheme.systemRed(context),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: active
                            ? blue
                            : IOSTheme.cardBackground(context),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      item.badgeCount! > 99 ? '99+' : '${item.badgeCount}',
                      style: const TextStyle(
                        inherit: false,
                        fontFamily: IOSTheme.fontFamily,
                        color: CupertinoColors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
