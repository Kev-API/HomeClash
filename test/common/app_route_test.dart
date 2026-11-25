import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

AppRoute _route({
  int id = 1,
  AppMatchKind kind = AppMatchKind.package,
  String value = 'com.anthropic.claude',
  String target = 'Claude',
  bool enabled = true,
}) {
  return AppRoute(
    id: id,
    profileId: 1,
    matchKind: kind,
    matchValue: value,
    target: target,
    enabled: enabled,
  );
}

void main() {
  group('appRouteLine', () {
    test('a package name compiles to PROCESS-NAME', () {
      expect(
        appRouteLine(_route(value: 'com.anthropic.claude', target: 'Claude')),
        'PROCESS-NAME,com.anthropic.claude,Claude',
      );
    });

    test('a process name compiles to PROCESS-NAME', () {
      expect(
        appRouteLine(
          _route(
            kind: AppMatchKind.process,
            value: 'Claude',
            target: 'Residential',
          ),
        ),
        'PROCESS-NAME,Claude,Residential',
      );
    });

    test('a path compiles to PROCESS-PATH', () {
      expect(
        appRouteLine(
          _route(
            kind: AppMatchKind.path,
            value: r'C:\Apps\Claude.exe',
            target: 'Residential',
          ),
        ),
        r'PROCESS-PATH,C:\Apps\Claude.exe,Residential',
      );
    });
  });

  group('effectiveAppRoutes', () {
    test('keeps the order the routes are given in', () {
      final routes = [
        _route(id: 1, value: 'com.a', target: 'A'),
        _route(id: 2, value: 'com.b', target: 'B'),
        _route(id: 3, value: 'com.c', target: 'C'),
      ];
      expect(
        effectiveAppRoutes(routes).map((route) => route.matchValue),
        ['com.a', 'com.b', 'com.c'],
      );
    });

    test('drops a disabled route', () {
      final routes = [
        _route(id: 1, value: 'com.a', target: 'A'),
        _route(id: 2, value: 'com.b', target: 'B', enabled: false),
      ];
      expect(
        effectiveAppRoutes(routes).map((route) => route.matchValue),
        ['com.a'],
      );
    });

    test('a repeated match keeps only its first route', () {
      final routes = [
        _route(id: 1, value: 'com.a', target: 'A'),
        _route(id: 2, value: 'com.a', target: 'B'),
      ];
      final kept = effectiveAppRoutes(routes);
      expect(kept, hasLength(1));
      expect(kept.single.target, 'A');
    });

    test('the same value under two kinds is two routes', () {
      final routes = [
        _route(id: 1, value: 'Claude', target: 'A'),
        _route(
          id: 2,
          kind: AppMatchKind.process,
          value: 'Claude',
          target: 'B',
        ),
      ];
      expect(effectiveAppRoutes(routes), hasLength(2));
    });

    test('drops a blank match or target', () {
      final routes = [
        _route(id: 1, value: '   ', target: 'A'),
        _route(id: 2, value: 'com.b', target: '  '),
      ];
      expect(effectiveAppRoutes(routes), isEmpty);
    });

    test('drops a value or target holding a comma', () {
      final routes = [
        _route(id: 1, value: 'com.a,com.b', target: 'A'),
        _route(id: 2, value: 'com.c', target: 'A,B'),
      ];
      expect(effectiveAppRoutes(routes), isEmpty);
    });

    test('trims the value it keeps', () {
      final routes = [_route(value: '  com.a  ', target: 'A')];
      expect(effectiveAppRoutes(routes).single.matchValue, 'com.a');
    });
  });

  group('appRouteLines', () {
    test('an empty set compiles to no lines', () {
      expect(appRouteLines(const []), isEmpty);
    });

    test('runs the routes in order', () {
      expect(
        appRouteLines([
          _route(id: 1, value: 'com.anthropic.claude', target: 'Claude'),
          _route(id: 2, kind: AppMatchKind.process, value: 'Claude', target: 'Claude'),
        ]),
        [
          'PROCESS-NAME,com.anthropic.claude,Claude',
          'PROCESS-NAME,Claude,Claude',
        ],
      );
    });

    test('a target may be DIRECT', () {
      expect(
        appRouteLines([_route(value: 'com.example', target: 'DIRECT')]),
        ['PROCESS-NAME,com.example,DIRECT'],
      );
    });
  });
}
