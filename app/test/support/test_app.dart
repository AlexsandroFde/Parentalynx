import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/time/clock.dart';
import 'package:parentalynx/features/app_management/presentation/services/app_icon_images.dart';
import 'package:parentalynx/shared/services/share_service.dart';
import 'package:parentalynx/shared/theme/app_frame.dart';
import 'package:parentalynx/shared/theme/app_theme.dart';

import 'fakes.dart';

/// Tamanho logico de um celular comum, usado nos testes de widget e nas capturas.
const Size phoneSize = Size(392, 850);

/// Monta [child] dentro do tema e da localizacao do app.
///
/// Os servicos de interface ([ShareService] e [Clock]) vem de [di], como no app. Os BLoCs de
/// que a tela precisa sao montados pelo proprio teste em volta de [child].
Future<void> pumpWidgetInApp(
  WidgetTester tester,
  Widget child, {
  required GetIt di,
  Brightness brightness = Brightness.light,
  Size size = phoneSize,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  await initializeDateFormatting('pt_BR');
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = size * 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<ShareService>.value(value: di<ShareService>()),
        RepositoryProvider<Clock>.value(value: di<Clock>()),
        RepositoryProvider<AppIconImages>.value(value: const NoAppIconImages()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
        locale: appLocale,
        supportedLocales: const <Locale>[appLocale],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: wrapAppContent,
        home: child,
      ),
    ),
  );
  await tester.pump();
}

bool _fontsLoaded = false;

/// Carrega as fontes reais (Roboto e icones) do SDK do Flutter, para que o layout e as capturas
/// de tela dos testes correspondam a um aparelho, em vez dos blocos da fonte de teste.
///
/// E chamada por `test/flutter_test_config.dart` antes de cada arquivo de teste. Nao chame de
/// dentro de um `testWidgets`: a carga depende de E/S real, que nao avanca no tempo simulado.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) {
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    return;
  }
  final String fontsDir = '$flutterRoot/bin/cache/artifacts/material_fonts';
  final Map<String, List<String>> families = <String, List<String>>{
    'Roboto': <String>[
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
      'roboto-light.ttf',
    ],
    'MaterialIcons': <String>['materialicons-regular.otf'],
  };
  for (final MapEntry<String, List<String>> family in families.entries) {
    final FontLoader loader = FontLoader(family.key);
    bool any = false;
    for (final String file in family.value) {
      final File font = File('$fontsDir/$file');
      if (font.existsSync()) {
        final Uint8List bytes = font.readAsBytesSync();
        loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
        any = true;
      }
    }
    if (any) {
      await loader.load();
    }
  }
  _fontsLoaded = true;
}

/// Compara a tela atual com a captura de referencia `screenshots/<name>.png`, na pasta do
/// proprio arquivo de teste.
///
/// Para gerar ou atualizar as capturas: `flutter test --update-goldens --tags screenshot`.
/// As capturas servem para revisar o visual das telas sem um aparelho.
Future<void> expectScreenshot(WidgetTester tester, String name) async {
  await expectLater(find.byType(MaterialApp).first, matchesGoldenFile('screenshots/$name.png'));
}
