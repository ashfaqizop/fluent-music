import 'package:app/design_system/settings/appearance_settings.dart';
import 'package:app/design_system/settings/appearance_settings_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Settings screen's Appearance section (Masterdoc §16), the seed for
/// later phases' settings sections. Controls density mode, window backdrop,
/// accent color source, and motion level — everything Phase 3 introduces.
class SettingsScreen extends ConsumerWidget {
  /// Creates the settings screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appearanceSettingsProvider);
    final controller = ref.read(appearanceSettingsProvider.notifier);

    return ScaffoldPage(
      header: const PageHeader(title: Text('Settings')),
      content: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Appearance',
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 12),
          _SettingRow(
            label: 'Density',
            child: ComboBox<DensityMode>(
              value: settings.densityMode,
              items: const [
                ComboBoxItem(value: DensityMode.hybrid, child: Text('Hybrid')),
                ComboBoxItem(
                  value: DensityMode.spacious,
                  child: Text('Spacious (Apple Music style)'),
                ),
                ComboBoxItem(
                  value: DensityMode.compact,
                  child: Text('Compact (power user)'),
                ),
              ],
              onChanged: (mode) {
                if (mode != null) controller.setDensityMode(mode);
              },
            ),
          ),
          _SettingRow(
            label: 'Window backdrop',
            child: ComboBox<BackdropMode>(
              value: settings.backdropMode,
              items: const [
                ComboBoxItem(value: BackdropMode.mica, child: Text('Mica')),
                ComboBoxItem(
                  value: BackdropMode.acrylic,
                  child: Text('Acrylic'),
                ),
                ComboBoxItem(value: BackdropMode.none, child: Text('None')),
              ],
              onChanged: (mode) {
                if (mode != null) controller.setBackdropMode(mode);
              },
            ),
          ),
          _SettingRow(
            label: 'Accent color',
            child: ComboBox<AccentMode>(
              value: settings.accentMode,
              items: const [
                ComboBoxItem(
                  value: AccentMode.windows,
                  child: Text('Follow Windows accent'),
                ),
                ComboBoxItem(value: AccentMode.custom, child: Text('Custom')),
              ],
              onChanged: (mode) {
                if (mode != null) controller.setAccentMode(mode);
              },
            ),
          ),
          if (settings.accentMode == AccentMode.custom)
            _SettingRow(
              label: 'Custom accent color',
              child: Wrap(
                spacing: 8,
                children: [
                  for (final color in Colors.accentColors)
                    _AccentSwatch(
                      color: color,
                      selected: settings.customAccentColor == color,
                      onTap: () => controller.setCustomAccentColor(color),
                    ),
                ],
              ),
            ),
          _SettingRow(
            label: 'Motion',
            child: ToggleSwitch(
              checked: settings.motionLevel == MotionLevel.full,
              onChanged: (checked) => controller.setMotionLevel(
                checked ? MotionLevel.full : MotionLevel.reduced,
              ),
              content: Text(
                settings.motionLevel == MotionLevel.full
                    ? 'Full motion'
                    : 'Reduced motion',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 200, child: Text(label)),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Colors.white, width: 2) : null,
        ),
      ),
    );
  }
}
