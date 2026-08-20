import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../providers/language_provider.dart';
import '../providers/main_color_provider.dart';

/// App bar actions shared by every top-level screen: a language switcher
/// (English/Khmer), a theme-color picker, and — when [onDisconnect] is
/// given — a disconnect button. Pass `null` for [onDisconnect] on screens
/// with nothing to disconnect from yet (e.g. the pairing form).
List<Widget> buildAppBarActions({
  required BuildContext context,
  required WidgetRef ref,
  VoidCallback? onDisconnect,
}) {
  final AppLanguage language = ref.watch(appLanguageProvider);
  final AppStrings strings = AppStrings(language);

  return [
    PopupMenuButton<AppLanguage>(
      tooltip: strings.languageTooltip,
      icon: const Icon(Icons.language),
      initialValue: language,
      onSelected: (final AppLanguage selected) =>
          ref.read(appLanguageProvider.notifier).setLanguage(selected),
      itemBuilder: (final BuildContext _) => const [
        CheckedPopupMenuItem<AppLanguage>(
          value: AppLanguage.en,
          child: Text('English'),
        ),
        CheckedPopupMenuItem<AppLanguage>(
          value: AppLanguage.km,
          child: Text('ខ្មែរ'),
        ),
      ],
    ),
    IconButton(
      tooltip: strings.colorTooltip,
      icon: const Icon(Icons.palette_outlined),
      onPressed: () => _showColorPicker(context, ref, strings),
    ),
    if (onDisconnect != null)
      IconButton(
        tooltip: strings.disconnectTooltip,
        icon: const Icon(Icons.link_off),
        onPressed: onDisconnect,
      ),
  ];
}

Future<void> _showColorPicker(
  final BuildContext context,
  final WidgetRef ref,
  final AppStrings strings,
) {
  final Color current = ref.read(mainColorProvider);
  return showDialog<void>(
    context: context,
    builder: (final BuildContext dialogContext) {
      return AlertDialog(
        title: Text(strings.chooseColorTitle),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: kMainColorOptions.map((final Color color) {
            final bool selected = color.toARGB32() == current.toARGB32();
            return GestureDetector(
              onTap: () {
                ref.read(mainColorProvider.notifier).setMainColor(color);
                Navigator.of(dialogContext).pop();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(color: Colors.black87, width: 3)
                      : null,
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      );
    },
  );
}
