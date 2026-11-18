import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/browser_app.dart';

/// Entrada do aplicativo principal (modo responsavel e modo crianca).
Future<void> main() async {
  final AppComposition composition = await bootstrap();
  runApp(ParentaLynxApp(di: composition.di, navigatorKey: composition.navigatorKey));
}

/// Entrada do navegador gerenciado.
///
/// A `BrowserActivity` nativa inicia um motor Flutter proprio com este ponto de entrada, para
/// que o tempo no navegador seja contado como um app separado.
@pragma('vm:entry-point')
Future<void> browserMain() async {
  runApp(BrowserApp(di: await bootstrapBrowser()));
}
