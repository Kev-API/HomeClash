import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:prism_ui/color.dart';

import 'preferences.dart';
import 'system.dart';
import 'task.dart';

typedef MigrationTransform =
    Future<MigrationData> Function(Map<String, Object?> configMap);

abstract interface class MigrationStore {
  /// False when the backing store could not be opened at all, as opposed to a
  /// store that opened but holds nothing.
  Future<bool> get isAvailable;

  Future<Map<String, Object?>?> getConfigMap();

  Future<int> getVersion();

  Future<Map<String, Object?>?> getClashConfigMap();

  Future<void> restore(MigrationData data);

  Future<bool> saveConfig(Config config);

  Future<void> clearClashConfig();

  Future<void> setVersion(int version);

  Future<int> getUpgradeVersion();

  Future<void> setUpgradeVersion(int version);
}

class _AppMigrationStore implements MigrationStore {
  const _AppMigrationStore();

  @override
  Future<bool> get isAvailable => preferences.isInit;

  @override
  Future<Map<String, Object?>?> getConfigMap() => preferences.getConfigMap();

  @override
  Future<int> getVersion() => preferences.getVersion();

  @override
  Future<Map<String, Object?>?> getClashConfigMap() =>
      preferences.getClashConfigMap();

  @override
  Future<void> restore(MigrationData data) {
    return database.restore(
      data.profiles,
      data.scripts,
      data.rules,
      data.disabledRules,
      data.proxyGroups,
      clashProviders: data.clashProviders,
    );
  }

  @override
  Future<bool> saveConfig(Config config) => preferences.saveConfig(config);

  @override
  Future<void> clearClashConfig() => preferences.clearClashConfig();

  @override
  Future<void> setVersion(int version) => preferences.setVersion(version);

  @override
  Future<int> getUpgradeVersion() => preferences.getUpgradeVersion();

  @override
  Future<void> setUpgradeVersion(int version) =>
      preferences.setUpgradeVersion(version);
}

class Migration {
  final MigrationStore _store;
  final MigrationTransform _migrateV0;

  Migration({required MigrationStore store, MigrationTransform? migrateV0})
    : _store = store,
      _migrateV0 = migrateV0 ?? oldToNowTask;

  static const currentVersion = 1;

  /// One-off setting changes for upgrades, apart from [currentVersion], which
  /// backups carry and an older app refuses when it is newer than its own.
  static const upgradeVersion = 5;

  /// Steps that set a default rather than repair an old one, so a fresh
  /// install runs them as well.
  static const _runsOnFirstLaunch = {5};

  static const Map<int, Config Function(Config config)> _upgrades = {
    1: _resetThemeColors,
    2: _keepGlassLook,
    3: _followSystemColors,
    4: _turnOffSidebarBlur,
    5: _turnOnTunOnDesktop,
  };

  Future<Config> run() async {
    final configMap = await _store.getConfigMap();
    final migrated = await _migrate(
      configMap,
      beforeSave: configMap == null ? _applyFirstLaunchDefaults : null,
    );
    if (migrated.saveFailed) {
      return migrated.config;
    }
    final config = migrated.config;
    return _upgrade(config, installed: configMap != null);
  }

  Config _applyFirstLaunchDefaults(Config config) {
    var upgraded = config;
    for (final version in _runsOnFirstLaunch) {
      upgraded = _upgrades[version]!(upgraded);
    }
    return upgraded;
  }

  Future<Config> _upgrade(Config config, {required bool installed}) async {
    final from = await _store.getUpgradeVersion();
    if (from >= upgradeVersion) {
      return config;
    }
    var upgraded = config;
    for (var version = from + 1; version <= upgradeVersion; version++) {
      // A first launch runs the steps that set a product default too, so a new
      // user gets the same starting state as an upgraded one.
      if (installed || _runsOnFirstLaunch.contains(version)) {
        upgraded = _upgrades[version]!(upgraded);
      }
    }
    if (upgraded != config && !await _store.saveConfig(upgraded)) {
      return config;
    }
    await _store.setUpgradeVersion(upgradeVersion);
    return upgraded;
  }

  Future<({Config config, bool saveFailed})> _migrate(
    Map<String, Object?>? configMap, {
    Config Function(Config config)? beforeSave,
  }) async {
    var oldVersion = await _store.getVersion();
    Config? config;
    if (oldVersion > currentVersion) {
      throw StateError(
        'Local data version $oldVersion is newer than $currentVersion.',
      );
    }
    if (oldVersion == currentVersion) {
      if (configMap != null && _isV0(configMap)) {
        try {
          config = Config.strictFromJson(configMap);
        } catch (_) {
          oldVersion = 0;
        }
      } else {
        config = Config.realFromJson(configMap);
      }
      if (config != null) {
        final storedDavPassword = _getStoredDavPassword(configMap);
        final hasPlainTextDavPassword =
            storedDavPassword != null &&
            storedDavPassword == config.davProps?.password;
        if (hasPlainTextDavPassword && !await _store.saveConfig(config)) {
          throw StateError('Failed to obfuscate the legacy WebDAV password');
        }
        return (config: config, saveFailed: false);
      }
    }

    MigrationData data = MigrationData(configMap: configMap);
    var shouldClearClashConfig = false;
    if (oldVersion == 0) {
      final clashConfigMap = await _store.getClashConfigMap();
      if (_isV0(configMap) && configMap != null) {
        final legacyConfigMap = Map<String, Object?>.from(configMap);
        if (clashConfigMap != null) {
          legacyConfigMap['patchClashConfig'] = clashConfigMap;
          shouldClearClashConfig = true;
        }
        data = await _migrateV0(legacyConfigMap);
      } else if (clashConfigMap != null) {
        final currentConfigMap = Map<String, Object?>.from(
          configMap ?? const {},
        );
        currentConfigMap.putIfAbsent('patchClashConfig', () => clashConfigMap);
        data = MigrationData(configMap: currentConfigMap);
        shouldClearClashConfig = true;
      }
    }

    config = Config.realFromJson(data.configMap);
    await _store.restore(data);
    final configToSave = beforeSave?.call(config) ?? config;
    if (!await _store.saveConfig(configToSave)) {
      // An unopenable store is reported later by the corrupt-cache dialog,
      // which offers a reset; failing here would hide that path.
      if (await _store.isAvailable) {
        throw StateError('Failed to save migrated preferences');
      }
      return (config: config, saveFailed: true);
    }
    if (shouldClearClashConfig) {
      await _store.clearClashConfig();
    }
    await _store.setVersion(currentVersion);
    return (config: configToSave, saveFailed: false);
  }
}

Config _resetThemeColors(Config config) => config.copyWith(
  themeProps: config.themeProps.copyWith(
    primaryColor: defaultPrimaryColor,
    primaryColors: defaultPrimaryColors,
    colorStyle: ColorStyle.vivid,
  ),
);

// The standard glass became the ultra tier when a lighter standard joined it.
Config _keepGlassLook(Config config) =>
    config.themeProps.liquidGlass == LiquidGlassMode.standard
    ? config.copyWith(
        themeProps: config.themeProps.copyWith(
          liquidGlass: LiquidGlassMode.ultra,
        ),
      )
    : config;

const _formerSystemColors = {
  0xFFAF52DE: 0xFFCB30E0,
  0xFFFF3B30: 0xFFFF383C,
  0xFFFF9500: 0xFFFF8D28,
};

// Every preset but blue moved to iOS 27's system color; one picked before moves.
Config _followSystemColors(Config config) {
  final theme = config.themeProps;
  return config.copyWith(
    themeProps: theme.copyWith(
      primaryColor:
          _formerSystemColors[theme.primaryColor] ?? theme.primaryColor,
      primaryColors: [
        ...{
          for (final color in theme.primaryColors)
            _formerSystemColors[color] ?? color,
        },
      ],
    ),
  );
}

// Releases stored sidebar blur on while its switch stayed hidden.
Config _turnOffSidebarBlur(Config config) =>
    config.copyWith(themeProps: config.themeProps.copyWith(sidebarBlur: false));

/// An app route reads which process opened a connection, and only the TUN
/// carries that reliably on a desktop: through the system proxy the core has to
/// ask the OS, which cannot always name the process — a reused connection or a
/// multiplexed one loses it. HomeClash is built around app routes, so a desktop
/// starts with the TUN on rather than leaving the feature silently dead.
///
/// Only the default changes: a user who turns it off keeps it off, since this
/// step runs once.
Config _turnOnTunOnDesktop(Config config) {
  if (!system.isDesktop) {
    return config;
  }
  final patch = config.patchClashConfig;
  if (patch.tun.enable) {
    return config;
  }
  return config.copyWith(
    patchClashConfig: patch.copyWith(tun: patch.tun.copyWith(enable: true)),
  );
}

bool _isV0(Map<String, Object?>? configMap) =>
    configMap?['proxiesStyle'] != null;

String? _getStoredDavPassword(Map<String, Object?>? configMap) {
  final dav = configMap?['davProps'] ?? configMap?['dav'];
  if (dav is! Map) {
    return null;
  }
  final password = dav['password'];
  return password is String && password.isNotEmpty ? password : null;
}

final migration = Migration(store: const _AppMigrationStore());
