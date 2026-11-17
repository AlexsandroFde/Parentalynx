import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'features/child/browser/presentation/browser_app.dart';

/// Entrada do aplicativo principal (modo responsavel e modo crianca).
Future<void> main() async {
  final ProviderContainer container = await bootstrap();
  runApp(UncontrolledProviderScope(container: container, child: const ParentaLynxApp()));
}

/// Entrada do navegador gerenciado.
///
/// A `BrowserActivity` nativa inicia um motor Flutter proprio com este ponto de entrada, para
/// que o tempo no navegador seja contado como um app separado.
@pragma('vm:entry-point')
Future<void> browserMain() async {
  final ProviderContainer container = await bootstrap();
  runApp(UncontrolledProviderScope(container: container, child: const BrowserApp()));
}
