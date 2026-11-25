import 'package:fl_clash/common/loopback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseExemptions', () {
    test('reads each name and SID pair', () {
      const report = '''
LoopbackExemptions:
 - AppContainerName: com.example.one
   SID: S-1-15-2-111
 - AppContainerName: com.example.two
   SID: S-1-15-2-222
''';
      final entries = parseExemptions(report);
      expect(entries, hasLength(2));
      expect(entries[0].appContainerName, 'com.example.one');
      expect(entries[0].sid, 'S-1-15-2-111');
      expect(entries[1].appContainerName, 'com.example.two');
      expect(entries[1].sid, 'S-1-15-2-222');
    });

    test('an empty report lists nothing', () {
      expect(parseExemptions(''), isEmpty);
    });

    test('a report with no entries lists nothing', () {
      expect(parseExemptions('LoopbackExemptions:\n\n'), isEmpty);
    });

    test('skips a SID with no name before it', () {
      const report = '''
   SID: S-1-15-2-orphan
 - AppContainerName: com.example.one
   SID: S-1-15-2-111
''';
      final entries = parseExemptions(report);
      expect(entries, hasLength(1));
      expect(entries.single.appContainerName, 'com.example.one');
    });

    test('ignores lines that carry no colon', () {
      const report = '''
LoopbackExemptions:
 - AppContainerName: com.example.one
   SID: S-1-15-2-111
some trailing note
''';
      expect(parseExemptions(report), hasLength(1));
    });

    test('the key match ignores case and surrounding space', () {
      const report = '''
  - APPCONTAINERNAME:   com.example.one
    sid:   S-1-15-2-111
''';
      final entries = parseExemptions(report);
      expect(entries, hasLength(1));
      expect(entries.single.appContainerName, 'com.example.one');
      expect(entries.single.sid, 'S-1-15-2-111');
    });
  });

  group('LoopbackExemption', () {
    test('two entries with the same name and SID are equal', () {
      const a = LoopbackExemption(
        appContainerName: 'com.example',
        sid: 'S-1',
      );
      const b = LoopbackExemption(
        appContainerName: 'com.example',
        sid: 'S-1',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a differing SID makes a different entry', () {
      const a = LoopbackExemption(
        appContainerName: 'com.example',
        sid: 'S-1',
      );
      const b = LoopbackExemption(
        appContainerName: 'com.example',
        sid: 'S-2',
      );
      expect(a, isNot(b));
    });
  });
}
