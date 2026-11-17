import 'dart:async';

import 'support/test_app.dart';

/// Executado pelo `flutter test` antes de cada arquivo de teste.
///
/// Carrega as fontes reais uma vez, fora da zona de tempo simulado dos testes de widget, para
/// que o layout e as capturas de tela correspondam ao que aparece em um aparelho.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  await testMain();
}
