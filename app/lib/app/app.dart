import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/config/app_config.dart';
import '../core/platform/native_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Raiz do aplicativo principal (os dois modos).
class ParentaLynxApp extends ConsumerWidget {
  const ParentaLynxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nativeEventsBindingProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: appLocale,
      supportedLocales: const <Locale>[appLocale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: wrapAppContent,
    );
  }
}

const Locale appLocale = Locale('pt', 'BR');

/// Envolve o conteudo do app: ponte de tema para pacotes que ainda usam o Material embutido
/// no SDK (graficos e WebView) e limite de escala de fonte, para o layout nao quebrar com
/// fontes muito grandes sem ignorar a preferencia de acessibilidade.
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
