/*
 * FICHIER : lib/widgets/ios_date_picker_field.dart
 *
 * Champ "date" iOS — affiche un row tappable qui ouvre un
 * CupertinoDatePicker dans un modal sheet.
 */

import 'package:flutter/cupertino.dart';
import '../core/cupertino_theme.dart';

class IOSDatePickerField extends StatelessWidget {
  final DateTime? value;
  final String placeholder;
  final IconData icon;
  final ValueChanged<DateTime> onChanged;
  final DateTime? minimumDate;
  final DateTime? maximumDate;

  const IOSDatePickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Sélectionner',
    this.icon = CupertinoIcons.calendar,
    this.minimumDate,
    this.maximumDate,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final label = hasValue
        ? '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}'
        : placeholder;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _show(context),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: IOSTheme.tertiaryBackground(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: IOSTheme.tertiaryLabel(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: IOSTheme.body(context).copyWith(
                  color: hasValue
                      ? IOSTheme.label(context)
                      : IOSTheme.placeholder(context),
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_down,
                size: 14, color: IOSTheme.tertiaryLabel(context)),
          ],
        ),
      ),
    );
  }

  void _show(BuildContext context) {
    DateTime tmp = value ?? DateTime(2000, 1, 1);
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 320,
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
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
                child: Row(
                  children: [
                    Text('Date',
                        style: IOSTheme.title2(ctx).copyWith(fontSize: 18)),
                    const Spacer(),
                    CupertinoButton(
                      onPressed: () {
                        onChanged(tmp);
                        Navigator.pop(ctx);
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: tmp,
                  minimumDate: minimumDate ?? DateTime(1920),
                  maximumDate: maximumDate ?? DateTime.now(),
                  onDateTimeChanged: (d) => tmp = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
