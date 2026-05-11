/*
 * FICHIER : lib/widgets/ios_phone_field.dart
 *
 * Widget réutilisable — champ téléphone iOS avec sélecteur de pays modal.
 * — Pill pays à gauche (drapeau + indicatif + chevron)
 * — Champ chiffres à droite (Expanded)
 * — Picker iOS modal (drag handle + liste de pays)
 *
 * Utilisé dans : login_screen, register_admin_screen, register_member_screen.
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/countries.dart';
import '../core/cupertino_theme.dart';

/// Liste des pays autorisés (Côte d'Ivoire + voisins + FR/US)
const _allowedCountryCodes = [
  'CI', 'FR', 'US', 'CM', 'BF', 'NE', 'TG', 'BJ', 'GH', 'NG',
];

class IOSPhoneField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String placeholder;

  /// Callback déclenché quand le numéro complet (+225XXXXXXXX) change.
  final ValueChanged<String>? onCompletePhoneChanged;

  /// Callback quand l'utilisateur appuie sur "valider" sur le clavier.
  final VoidCallback? onSubmitted;

  /// Code pays initial (ISO 2 lettres). Défaut : 'CI'.
  final String initialCountryCode;

  const IOSPhoneField({
    super.key,
    required this.controller,
    this.focusNode,
    this.placeholder = 'Numéro',
    this.onCompletePhoneChanged,
    this.onSubmitted,
    this.initialCountryCode = 'CI',
  });

  @override
  State<IOSPhoneField> createState() => _IOSPhoneFieldState();
}

class _IOSPhoneFieldState extends State<IOSPhoneField> {
  late final List<Country> _allowedCountries =
      countries.where((c) => _allowedCountryCodes.contains(c.code)).toList();

  late Country _selectedCountry = _allowedCountries.firstWhere(
    (c) => c.code == widget.initialCountryCode,
    orElse: () => _allowedCountries.first,
  );

  void _emitComplete() {
    final digits =
        widget.controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    widget.onCompletePhoneChanged?.call('+${_selectedCountry.dialCode}$digits');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildCountryPill(),
        const SizedBox(width: 10),
        Expanded(child: _buildNumberField()),
      ],
    );
  }

  Widget _buildCountryPill() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showCountryPicker,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: IOSTheme.tertiaryBackground(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_selectedCountry.flag,
                style: const TextStyle(fontSize: 22, height: 1.0)),
            const SizedBox(width: 8),
            Text(
              '+${_selectedCountry.dialCode}',
              style: TextStyle(
                inherit: false,
                fontFamily: IOSTheme.fontFamily,
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: IOSTheme.label(context),
                letterSpacing: -0.41,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_down,
              size: 12,
              color: IOSTheme.tertiaryLabel(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: IOSTheme.tertiaryBackground(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CupertinoTextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        keyboardType: TextInputType.phone,
        placeholder: widget.placeholder,
        decoration: const BoxDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        style: IOSTheme.body(context).copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
        placeholderStyle: IOSTheme.body(context).copyWith(
          color: IOSTheme.placeholder(context),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(15),
        ],
        onChanged: (_) {
          _emitComplete();
          setState(() {});
        },
        onSubmitted: (_) => widget.onSubmitted?.call(),
      ),
    );
  }

  void _showCountryPicker() {
    FocusScope.of(context).unfocus();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.55,
          decoration: BoxDecoration(
            color: IOSTheme.cardBackground(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                      Text('Choisir un pays',
                          style: IOSTheme.title2(ctx).copyWith(fontSize: 20)),
                      const Spacer(),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'OK',
                          style: TextStyle(
                            inherit: false,
                            fontFamily: IOSTheme.fontFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: IOSTheme.systemBlue(ctx),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: _allowedCountries.length,
                    separatorBuilder: (_, __) => Container(
                      margin: const EdgeInsets.only(left: 64),
                      height: 0.5,
                      color: IOSTheme.separator(ctx),
                    ),
                    itemBuilder: (_, i) {
                      final c = _allowedCountries[i];
                      final isSelected = c.code == _selectedCountry.code;
                      final blue = IOSTheme.systemBlue(ctx);

                      return CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() => _selectedCountry = c);
                          _emitComplete();
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          color: CupertinoColors.transparent,
                          child: Row(
                            children: [
                              Text(c.flag,
                                  style: const TextStyle(fontSize: 26)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(c.name,
                                    style: IOSTheme.body(ctx),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Text('+${c.dialCode}',
                                  style: IOSTheme.subhead(ctx).copyWith(
                                      color: IOSTheme.secondaryLabel(ctx))),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 22,
                                child: isSelected
                                    ? Icon(CupertinoIcons.checkmark,
                                        color: blue, size: 20)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
