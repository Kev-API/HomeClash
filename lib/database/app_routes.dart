part of 'database.dart';

@DataClassName('RawAppRoute')
class AppRoutes extends Table {
  @override
  String get tableName => 'app_routes';

  IntColumn get id => integer()();

  IntColumn get profileId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade)();

  TextColumn get matchKind => textEnum<AppMatchKind>()();

  /// The package name, executable name or executable path to match.
  TextColumn get matchValue => text()();

  /// Where the app's traffic leaves: DIRECT, a proxy group or a local proxy.
  TextColumn get target => text()();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  TextColumn get order => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE (profile_id, match_kind, match_value)',
  ];
}

@DriftAccessor(tables: [AppRoutes])
class AppRoutesDao extends DatabaseAccessor<Database> with _$AppRoutesDaoMixin {
  AppRoutesDao(super.attachedDatabase);

  Selectable<AppRoute> queryByProfile(int profileId) {
    final query = select(appRoutes)
      ..where((t) => t.profileId.equals(profileId))
      ..orderBy([
        (t) => OrderingTerm.asc(t.order),
        (t) => OrderingTerm.asc(t.matchValue),
      ]);
    return query.map(
      (row) => AppRoute(
        id: row.id,
        profileId: row.profileId,
        matchKind: row.matchKind,
        matchValue: row.matchValue,
        target: row.target,
        enabled: row.enabled,
        order: row.order,
      ),
    );
  }

  Future<void> put(AppRoute route) =>
      into(appRoutes).insertOnConflictUpdate(_companionOf(route));

  Future<void> putAll(Iterable<AppRoute> routes) => batch((b) {
    b.insertAllOnConflictUpdate(appRoutes, routes.map(_companionOf));
  });

  Future<int> deleteById(int id) =>
      (delete(appRoutes)..where((t) => t.id.equals(id))).go();

  Future<int> deleteByProfile(int profileId) =>
      (delete(appRoutes)..where((t) => t.profileId.equals(profileId))).go();

  /// Keeps a route pointing at a target that was renamed.
  Future<void> renameTarget(
    int profileId, {
    required String oldName,
    required String newName,
  }) {
    final stmt = update(appRoutes);
    stmt.where((t) => t.profileId.equals(profileId) & t.target.equals(oldName));
    return stmt.write(AppRoutesCompanion(target: Value(newName)));
  }

  /// Profiles that route anything to one of [names], so a delete can warn.
  Future<Map<int, Set<String>>> targetsNaming(Set<String> names) async {
    final query = selectOnly(appRoutes, distinct: true)
      ..addColumns([appRoutes.profileId, appRoutes.target])
      ..where(appRoutes.target.isIn(names));
    final targets = <int, Set<String>>{};
    for (final row in await query.get()) {
      targets
          .putIfAbsent(row.read(appRoutes.profileId)!, () => {})
          .add(row.read(appRoutes.target)!);
    }
    return targets;
  }

  void setAllWithBatch(Batch batch, Iterable<AppRoute> items) {
    appRoutes.setAll(
      batch,
      items.map(_companionOf),
      deleteFilter: (_) => const Constant(true),
      preDelete: true,
    );
  }

  void putAllWithBatch(Batch batch, Iterable<AppRoute> items) {
    batch.insertAllOnConflictUpdate(appRoutes, items.map(_companionOf));
  }

  AppRoutesCompanion _companionOf(AppRoute route) {
    return AppRoutesCompanion.insert(
      id: Value(route.id),
      profileId: route.profileId,
      matchKind: route.matchKind,
      matchValue: route.matchValue,
      target: route.target,
      enabled: Value(route.enabled),
      order: Value(route.order),
    );
  }
}

extension RawAppRouteExt on RawAppRoute {
  AppRoute toAppRoute() {
    return AppRoute(
      id: id,
      profileId: profileId,
      matchKind: matchKind,
      matchValue: matchValue,
      target: target,
      enabled: enabled,
      order: order,
    );
  }
}
