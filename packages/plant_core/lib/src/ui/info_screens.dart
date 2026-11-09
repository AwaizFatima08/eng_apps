import 'package:flutter/material.dart';

import '../settings.dart';
import '../units.dart';

const String kDisclaimer =
    'These tools give engineering estimates only. Results depend on the '
    'inputs, assumptions and simplifications listed with each tool. Always '
    'verify against the governing standard, the manufacturer\'s data and '
    'your plant\'s procedures before using a result for design, purchase, '
    'calibration acceptance or safety decisions. HomiLabs accepts no '
    'liability for the use of these results.';

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key, required this.onAccept});
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final config = ConfigScope.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 24),
                      Icon(
                        Icons.engineering,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        config.appName,
                        style: text.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        config.discipline,
                        style: text.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Text('Before you start', style: text.titleLarge),
                      const SizedBox(height: 8),
                      Text(kDisclaimer, style: text.bodyLarge),
                      const SizedBox(height: 12),
                      Text(
                        'Works fully offline. No account, no ads, no data leaves your phone.',
                        style: text.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onAccept,
                      child: const Text('I understand'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Default units', style: text.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (v, label) in const [
                (UnitSystem.metric, 'Metric (bar, °C, mm)'),
                (UnitSystem.imperial, 'US (psi, °F, in)'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: s.unitSystem == v,
                  onSelected: (_) => s.unitSystem = v,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'You can still pick any unit on each field.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 24),
          Text('Theme', style: text.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (v, label) in const [
                (ThemeMode.system, 'System'),
                (ThemeMode.light, 'Light'),
                (ThemeMode.dark, 'Dark'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: s.themeMode == v,
                  onSelected: (_) => s.themeMode = v,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ConfigScope.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${c.appName} — ${c.discipline}', style: text.titleLarge),
          Text('Version ${c.version}', style: text.bodySmall),
          const SizedBox(height: 12),
          Text(c.aboutText, style: text.bodyMedium),
          const SizedBox(height: 20),
          Text('Disclaimer', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(kDisclaimer, style: text.bodyMedium),
          const SizedBox(height: 20),
          Text('Privacy', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'The app works offline. It has no account, no ads and no analytics, '
            'and it does not collect, store or share personal data. Your unit '
            'and theme choices are stored only on this device.'
            '${c.privacyUrl != null ? '\n\nPrivacy policy: ${c.privacyUrl}' : ''}',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 20),
          Text('Tools and references', style: text.titleMedium),
          const SizedBox(height: 4),
          for (final t in c.tools)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '• ${t.title}: ${t.references.join('; ')}',
                style: text.bodySmall,
              ),
            ),
          const SizedBox(height: 20),
          Text('HomiLabs Plant Tools · homilabs.org', style: text.bodySmall),
        ],
      ),
    );
  }
}
