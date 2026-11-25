import 'package:fl_clash/enum/enum.dart';

/// An AI app whose traffic usually needs one clean, stable exit.
///
/// Each preset carries every name the same app is known by, because the core
/// reports a package name on Android and an executable name elsewhere. Applying
/// one is meant to be two taps: pick the app, pick the exit.
class AppRoutePreset {
  final String label;
  final List<String> packageNames;
  final List<String> processNames;

  const AppRoutePreset({
    required this.label,
    required this.packageNames,
    required this.processNames,
  });

  /// The match values a route is written with, in the kind each one needs.
  List<({AppMatchKind kind, String value})> get matches => [
    for (final name in packageNames)
      (kind: AppMatchKind.package, value: name),
    for (final name in processNames)
      (kind: AppMatchKind.process, value: name),
  ];
}

/// Ordered so the most used apps come first.
const appRoutePresets = <AppRoutePreset>[
  AppRoutePreset(
    label: 'Claude',
    packageNames: ['com.anthropic.claude'],
    processNames: ['Claude', 'claude.exe'],
  ),
  AppRoutePreset(
    label: 'ChatGPT',
    packageNames: ['com.openai.chatgpt'],
    processNames: ['ChatGPT', 'ChatGPT.exe'],
  ),
  AppRoutePreset(
    label: 'Gemini',
    packageNames: ['com.google.android.apps.bard'],
    processNames: [],
  ),
  AppRoutePreset(
    label: 'Copilot',
    packageNames: ['com.microsoft.copilot'],
    processNames: ['Copilot', 'Copilot.exe'],
  ),
  AppRoutePreset(
    label: 'Perplexity',
    packageNames: ['ai.perplexity.app.android'],
    processNames: [],
  ),
  AppRoutePreset(
    label: 'Grok',
    packageNames: ['ai.x.grok'],
    processNames: [],
  ),
];
