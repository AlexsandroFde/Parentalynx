import 'package:material_ui/material_ui.dart';

/// Idioma unico do app.
const Locale appLocale = Locale('pt', 'BR');

/// Envolve o conteudo do app: ponte de tema para pacotes que ainda usam o Material embutido
/// no SDK (graficos e WebView) e limite de escala de fonte, para o layout nao quebrar com
/// fontes muito grandes sem ignorar a preferencia de acessibilidade.
///
/// Usado pelos dois apps (principal e navegador gerenciado) e pelos testes.
Widget wrapAppContent(BuildContext context, Widget? child) {
  final MediaQueryData media = MediaQuery.of(context);
  return MediaQuery(
    data: media.copyWith(
      textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.6),
    ),
    // A ponte e marcada como temporaria pelo material_ui. Continua necessaria enquanto
    // fl_chart e webview_flutter importarem o Material do SDK.
    // ignore: deprecated_member_use
    child: MaterialUiCompatibilityBridge(child: child ?? const SizedBox.shrink()),
  );
}
