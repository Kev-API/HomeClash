import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every app that leaves through its own exit, in the order the core reads
/// them. The first rule a connection matches wins, so order is the feature.
class CustomAppRoutesView extends ConsumerWidget {
  final int profileId;

  const CustomAppRoutesView(this.profileId, {super.key});

  Future<void> _handleSelectExit(
    BuildContext context,
    WidgetRef ref,
    AppRoute route,
  ) async {
    final res = await showNestedSheet<String>(
      context,
      builder: (context) => Consumer(
        builder: (_, ref, _) {
          final appLocalizations = context.appLocalizations;
          final data = ref.watch(customProfileDataProvider(profileId));
          final groups = data?.proxyGroups ?? const <ProxyGroup>[];
          final named = data?.namedProxies ?? const <String>{};
          final nodeTypes = {
            for (final item
                in ref.watch(customProxiesProvider).value ??
                    const <CustomProxy>[])
              if (named.contains(item.name)) item.name: item.type,
          };
          final groupTypes = {
            for (final group in groups) group.name: group.type.name,
          };
          return SelectionSheet<String>(
            title: appLocalizations.appRouteExit,
            sections: [
              SelectionSection(
                label: appLocalizations.appRouteExit,
                items: [RuleTarget.DIRECT.value, RuleTarget.REJECT.value],
              ),
              SelectionSection(
                label: appLocalizations.localProxies,
                items: nodeTypes.keys.toList(),
                subtitleBuilder: (_, name) => nodeTypes[name],
              ),
              SelectionSection(
                label: appLocalizations.proxyGroup,
                items: groupTypes.keys.toList(),
                subtitleBuilder: (_, name) => groupTypes[name],
              ),
            ],
            labelBuilder: (item) => item,
            selectedOf: (_) => route.target,
            onSelected: (item) => Navigator.of(context).pop(item),
          );
        },
      ),
    );
    if (res == null || res == route.target) {
      return;
    }
    await ref
        .read(appRoutesProvider(profileId).notifier)
        .put(route.copyWith(target: res));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final routes = ref.watch(appRoutesProvider(profileId)).value;
    return Scaffold(
      title: appLocalizations.appRoutes,
      primaryAction: IconButtonData(
        glyph: AppGlyphs.add,
        tooltip: appLocalizations.appRouteAdd,
        onPressed: () => _handleAdd(context, ref),
      ),
      body: NullStatusSwitcher(
        isLoading: routes == null,
        isEmpty: routes?.isEmpty ?? true,
        isSearching: false,
        nullStatus: NullStatus(
          label: appLocalizations.appRoutesEmpty,
          illustration: NullStatusIllustration.proxies,
        ),
        child: PrismListView(
          padding: EdgeInsets.fromLTRB(
            16,
            context.contentTopPadding,
            16,
            24 + context.bottomInset,
          ),
          itemCount: routes?.length ?? 0,
          itemBuilder: (_, index) {
            final route = routes![index];
            return ItemPositionProvider(
              key: ValueKey(route.id),
              position: ItemPosition.get(index, routes.length),
              child: _AppRouteItem(
                profileId: profileId,
                route: route,
                onPressed: () => _handleSelectExit(context, ref, route),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Two taps: pick the preset (or type a name), then pick the exit.
  Future<void> _handleAdd(BuildContext context, WidgetRef ref) async {
    final preset = await _pickPreset(context);
    if (preset == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final exit = await _pickExit(context, ref);
    if (exit == null) {
      return;
    }
    final notifier = ref.read(appRoutesProvider(profileId).notifier);
    for (final match in preset.matches) {
      await notifier.put(
        AppRoute(
          profileId: profileId,
          matchKind: match.kind,
          matchValue: match.value,
          target: exit,
        ),
      );
    }
  }

  Future<AppRoutePreset?> _pickPreset(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return showNestedSheet<AppRoutePreset>(
      context,
      builder: (context) => SelectionSheet<AppRoutePreset>(
        title: appLocalizations.appRouteAdd,
        sections: const [
          SelectionSection(
            items: appRoutePresets,
            subtitleBuilder: _appRoutePresetSubtitle,
          ),
        ],
        labelBuilder: (item) => item.label,
        selectedOf: (_) => null,
        onSelected: (item) => Navigator.of(context).pop(item),
      ),
    );
  }

  static String _appRoutePresetSubtitle(
    BuildContext context,
    AppRoutePreset item,
  ) => [...item.packageNames, ...item.processNames].join(', ');

  Future<String?> _pickExit(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final data = ref.read(customProfileDataProvider(profileId));
    final groups = data?.proxyGroups ?? const <ProxyGroup>[];
    final named = data?.namedProxies ?? const <String>{};
    final nodes = [
      for (final item
          in ref.read(customProxiesProvider).value ?? const <CustomProxy>[])
        if (named.contains(item.name)) item.name,
    ];
    return showNestedSheet<String>(
      context,
      builder: (context) => SelectionSheet<String>(
        title: appLocalizations.appRouteExit,
        sections: [
          SelectionSection(
            items: [RuleTarget.DIRECT.value, RuleTarget.REJECT.value],
          ),
          SelectionSection(label: appLocalizations.localProxies, items: nodes),
          SelectionSection(
            label: appLocalizations.proxyGroup,
            items: [for (final group in groups) group.name],
          ),
        ],
        labelBuilder: (item) => item == RuleTarget.DIRECT.value
            ? appLocalizations.appRouteDirect
            : item,
        selectedOf: (_) => null,
        onSelected: (item) => Navigator.of(context).pop(item),
      ),
    );
  }
}

class _AppRouteItem extends ConsumerWidget {
  final int profileId;
  final AppRoute route;
  final VoidCallback onPressed;

  const _AppRouteItem({
    required this.profileId,
    required this.route,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref
        .watch(
          customProfileIssuesProvider(profileId).select(
            (state) =>
                SelectValue(state.appRoutes[route.id] ?? const <CustomIssue>[]),
          ),
        )
        .value;
    return DecorationListItem(
      invalid: issues.isNotEmpty,
      onPressed: onPressed,
      leading: GlyphIcon(
        AppGlyphs.devices,
        size: 32,
        color: context.colorScheme.onSurfaceVariant,
      ),
      contentPadding: const EdgeInsets.only(left: 16, right: 8),
      title: TooltipText(
        text: Text(
          route.matchValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      subtitle: Text(
        route.target,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Switch(
        value: route.enabled,
        onChanged: (value) => ref
            .read(appRoutesProvider(profileId).notifier)
            .setEnabled(route, value),
      ),
    );
  }
}
