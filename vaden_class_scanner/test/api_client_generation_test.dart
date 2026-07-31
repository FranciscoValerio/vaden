import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:vaden_class_scanner/src/flutter_builder.dart';

void main() {
  test(
    '@ApiClient classes are registered via their generated implementation '
    'instead of tearing off the abstract constructor (regression for #139)',
    () async {
      final fixtureSource = File(
        'test/fixtures/api_client_fixture.dart',
      ).readAsStringSync();

      // `vaden_core` (used by the fixture's `@ApiClient` import) isn't part
      // of the in-memory sourceAssets, so it needs to be loaded from the
      // real package resolution of the current isolate for the analyzer to
      // resolve it.
      final readerWriter = TestReaderWriter(rootPackage: 'pkg');
      await readerWriter.testing.loadIsolateSources();
      readerWriter.testing.writeString(
        AssetId('pkg', 'lib/api_client_fixture.dart'),
        fixtureSource,
      );

      final result = await testBuilder(
        FlutterVadenBuilder(),
        {},
        rootPackage: 'pkg',
        readerWriter: readerWriter,
        flattenOutput: true,
      );

      final output = result.readerWriter.testing.readString(
        AssetId('pkg', 'lib/vaden_application.dart'),
      );

      // Bug from #139: the abstract class constructor was torn off directly,
      // which fails to compile because LaunchApi is abstract.
      expect(output, isNot(contains('_injector.addLazySingleton(LaunchApi.new)')));

      // Fixed in #144: the class is registered via its generated
      // implementation instead.
      expect(
        output,
        contains('_injector.addLazySingleton<LaunchApi>(_LaunchApi.new)'),
      );
      expect(output, contains('class _LaunchApi implements LaunchApi'));
    },
  );
}
