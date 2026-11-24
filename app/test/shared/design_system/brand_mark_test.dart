import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/shared/design_system/design_system.dart';

/// O simbolo do app (`BrandMark`) e o icone do Android desenham as mesmas formas: ao redesenhar
/// um, o outro tem que acompanhar.
void main() {
  test('o BrandMark tem as mesmas formas do icone do app', () {
    final String xml = File('android/app/src/main/res/drawable/ic_launcher_foreground.xml')
        .readAsStringSync();
    final List<String> paths = <String>[
      for (final RegExpMatch match in RegExp('android:pathData="([^"]+)"').allMatches(xml))
        match[1]!,
    ];

    expect(paths, <String>[BrandShapes.silhouette, BrandShapes.amber]);
  });
}
