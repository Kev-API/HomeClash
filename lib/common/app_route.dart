import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

/// The rule action a [AppMatchKind] compiles to.
RuleAction _actionOf(AppMatchKind kind) => switch (kind) {
  AppMatchKind.package || AppMatchKind.process => RuleAction.PROCESS_NAME,
  AppMatchKind.path => RuleAction.PROCESS_PATH,
};

/// The rule line that sends [route]'s app to its target.
///
/// A package name and an executable name are both what the core reports for a
/// connection's owning process, so both use `PROCESS-NAME`; only a full path
/// needs `PROCESS-PATH`.
String appRouteLine(AppRoute route) {
  final action = _actionOf(route.matchKind);
  return '${action.value},${route.matchValue},${route.target}';
}

/// Routes that can be written as rules, in the order they must appear.
///
/// The core takes the first rule a connection matches, so a route only works
/// ahead of the domain and IP rules a profile already carries: one placed after
/// a `GEOSITE` or `MATCH` line never runs. Duplicates are dropped because a
/// package can only leave through one exit — the first route wins, matching
/// what the core would do with the second.
List<AppRoute> effectiveAppRoutes(Iterable<AppRoute> routes) {
  final seen = <String>{};
  final kept = <AppRoute>[];
  for (final route in routes) {
    if (!route.enabled) {
      continue;
    }
    final value = route.matchValue.trim();
    final target = route.target.trim();
    if (value.isEmpty || target.isEmpty) {
      continue;
    }
    // A rule line joins its fields with commas, so the core would read a value
    // or target holding one as cut short.
    if (value.contains(',') || target.contains(',')) {
      continue;
    }
    if (!seen.add('${route.matchKind.name}\u0000$value')) {
      continue;
    }
    kept.add(route.copyWith(matchValue: value, target: target));
  }
  return kept;
}

/// The rule lines [routes] compile to, ready to sit at the head of a profile's
/// rules.
List<String> appRouteLines(Iterable<AppRoute> routes) => [
  for (final route in effectiveAppRoutes(routes)) appRouteLine(route),
];
