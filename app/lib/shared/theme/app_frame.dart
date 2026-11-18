import 'package:material_ui/material_ui.dart';

/// Idioma unico do app.
const Locale appLocale = Locale('pt', 'BR');

/// Envolve o conteudo do app: ponte de tema para pacotes que ainda usam o Material embutido
/// no SDK (graficos e WebView) e limite de escala de fonte em 2x, o maior tamanho oferecido
/// pelo Android: a preferencia de acessibilidade e respeitada por inteiro e as telas sao
/// testadas nesse tamanho.
///
/// Usado pelos dois apps (principal e navegador gerenciado) e pelos testes.
Widget wrapAppContent(BuildContext context, Widget? child) {
  final MediaQueryData media = MediaQuery.of(context);
  return MediaQuery(
    data: media.copyWith(
      textScaler: media.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 2),
    ),
    // A ponte e marcada como temporaria pelo material_ui. Continua necessaria enquanto
    // fl_chart e webview_flutter importarem o Material do SDK.
    // ignore: deprecated_member_use
    child: MaterialUiCompatibilityBridge(child: child ?? const SizedBox.shrink()),
  );
}
