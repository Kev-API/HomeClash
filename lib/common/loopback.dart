import 'dart:io';

import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/common/system.dart';

/// The Windows in-box tool that edits AppContainer loopback exemptions.
///
/// Every `CheckNetIsolation` call here is the signed tool Windows ships, so the
/// feature needs no bundled binary — which is why this replaced the third-party
/// utility HomeClash used to carry.
const _checkNetIsolation = 'CheckNetIsolation.exe';

/// One AppContainer that may reach the local proxy port.
class LoopbackExemption {
  /// What the tool prints, e.g. `- AppContainerName: com.example.app`.
  final String appContainerName;

  /// The tool's `SID` line, unique per app.
  final String sid;

  const LoopbackExemption({
    required this.appContainerName,
    required this.sid,
  });

  @override
  bool operator ==(Object other) =>
      other is LoopbackExemption &&
      other.appContainerName == appContainerName &&
      other.sid == sid;

  @override
  int get hashCode => Object.hash(appContainerName, sid);
}

/// Reads and edits the AppContainer loopback list through the Windows tool.
///
/// Listing runs unprivileged: `-s` only reads the store. Adding and removing
/// change it machine-wide, so they go through an elevation prompt — the tool
/// keeps its own console there, which means its exit status is not readable
/// from here and a caller treats the prompt being accepted as the result.
class LoopbackExemptions {
  final Future<ProcessResult> Function(List<String> arguments) _list;
  final bool Function(String command, String arguments) _elevate;

  const LoopbackExemptions({
    Future<ProcessResult> Function(List<String> arguments)? list,
    bool Function(String command, String arguments)? elevate,
  }) : _list = list ?? _listUnelevated,
       _elevate = elevate ?? _runElevated;

  static Future<ProcessResult> _listUnelevated(List<String> arguments) {
    return Process.run(_checkNetIsolation, arguments);
  }

  static bool _runElevated(String command, String arguments) {
    final elevated = windows;
    if (elevated == null) {
      throw const LoopbackException(LoopbackFailure.unsupported);
    }
    if (!elevated.runas(command, arguments)) {
      throw const LoopbackException(LoopbackFailure.declined);
    }
    return true;
  }

  /// The exemptions already in place.
  Future<List<LoopbackExemption>> list() async {
    final result = await _list(['-s']);
    if (result.exitCode != 0) {
      throw LoopbackException(
        LoopbackFailure.failed,
        detail: '${result.stderr}',
      );
    }
    return parseExemptions('${result.stdout}');
  }

  /// Adds [exemption] once the user accepts the elevation prompt.
  void add(LoopbackExemption exemption) {
    _elevate(_checkNetIsolation, '-a -n=${exemption.appContainerName}');
  }

  /// Removes [exemption] once the user accepts the elevation prompt.
  void remove(LoopbackExemption exemption) {
    _elevate(_checkNetIsolation, '-d -n=${exemption.appContainerName}');
  }
}

/// Reads the `-s` report the tool prints.
///
/// Each entry is an `AppContainerName` line followed by an `SID` line; anything
/// else in the report is a header or a blank line and is skipped.
List<LoopbackExemption> parseExemptions(String report) {
  final entries = <LoopbackExemption>[];
  String? name;
  for (final raw in report.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      continue;
    }
    final colon = line.indexOf(':');
    if (colon < 0) {
      continue;
    }
    final key = line.substring(0, colon).trim().toLowerCase();
    final value = line.substring(colon + 1).trim();
    if (key.endsWith('appcontainername')) {
      name = value;
      continue;
    }
    if (key.endsWith('sid') && name != null && name.isNotEmpty) {
      entries.add(LoopbackExemption(appContainerName: name, sid: value));
      name = null;
    }
  }
  commonPrint.log('parsed ${entries.length} loopback exemptions');
  return entries;
}

enum LoopbackFailure { unsupported, declined, failed }

class LoopbackException implements Exception {
  final LoopbackFailure failure;
  final String? detail;

  const LoopbackException(this.failure, {this.detail});

  @override
  String toString() =>
      'LoopbackException(${failure.name}${detail == null ? '' : ': $detail'})';
}
