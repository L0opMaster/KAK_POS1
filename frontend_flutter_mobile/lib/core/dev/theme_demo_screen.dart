import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/pos_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/main_color_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/l10n_extensions.dart';

/// TEMPORARY Day 3 verification screen — exists only to exercise and
/// visually confirm the theme/main-color/localization foundation this day
/// builds. Not the real app shell.
///
/// This is deliberately NOT the full Settings UI (that's Day 19 scope) and
/// NOT the Login/POS shell (Day 5 scope) — it is the "minimum test/demo
/// control" the task instructions call for so main-color persistence,
/// instant theme rebuild, dark mode, and Khmer text scaling can be verified
/// by hand before later days build the real screens that will eventually
/// replace this one (Settings' color picker, the app's real home shell).
///
/// MODIFIED Day 4: added a logged-in-user banner + logout action so the
/// full auth round-trip (login → this screen → logout → back to
/// LoginScreen) is manually testable before Day 5 builds the real
/// post-login home. See DAY_04.md section 6.
class ThemeDemoScreen extends ConsumerWidget {
  const ThemeDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedColor = ref.watch(mainColorProvider);
    final language = ref.watch(appLanguageProvider);
    final themeModeNotifier = ref.watch(themeModeProvider);
    final currentUser = ref.watch(currentUserProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.authLogout,
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(PosTheme.spacingLg),
        children: [
          if (currentUser != null) ...[
            Text(
              'Logged in as ${currentUser.fullName} (${currentUser.email})',
              style: TextStyle(
                fontSize: 13,
                color: PosTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: PosTheme.spacingLg),
          ],
          Text(
            l10n.settingsMainColor,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: PosTheme.spacingSm),
          Wrap(
            spacing: PosTheme.spacingSm,
            runSpacing: PosTheme.spacingSm,
            children: kMainColorOptions.map((color) {
              final bool selected = selectedColor.toARGB32() == color.toARGB32();
              return GestureDetector(
                onTap: () =>
                    ref.read(mainColorProvider.notifier).setMainColor(color),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.black : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const Divider(height: PosTheme.spacingXxl),
          Text(
            l10n.settingsLanguage,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: PosTheme.spacingSm),
          SegmentedButton<AppLanguage>(
            segments: const [
              ButtonSegment(value: AppLanguage.en, label: Text('English')),
              ButtonSegment(value: AppLanguage.km, label: Text('ខ្មែរ')),
            ],
            selected: {language},
            onSelectionChanged: (selection) => ref
                .read(appLanguageProvider.notifier)
                .setLanguage(selection.first),
          ),
          const Divider(height: PosTheme.spacingXxl),
          Text('Theme mode', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: PosTheme.spacingSm),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {themeModeNotifier.value},
            onSelectionChanged: (selection) => selection.first == ThemeMode.dark
                ? themeModeNotifier.setDark()
                : themeModeNotifier.setLight(),
          ),
          const Divider(height: PosTheme.spacingXxl),
          // Khmer text-scaling proof: this English label and its Khmer
          // counterpart below sit at the same nominal font size, so a
          // visible size difference confirms khmerAwareTextScaler is wired
          // through MaterialApp.builder — not just present in code.
          Text('English text stays the same size (${l10n.commonSave})',
              style: const TextStyle(fontSize: 15)),
          const SizedBox(height: PosTheme.spacingSm),
          const Text('អក្សរខ្មែរធំជាងបន្តិច (Khmer text is slightly larger)',
              style: TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}
