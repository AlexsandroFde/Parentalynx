import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/platform/native_providers.dart';
import 'browser_page.dart';

/// Raiz do navegador gerenciado, executada pelo ponto de entrada `browserMain`.
///
/// Roda em um motor Flutter proprio, dentro da `BrowserActivity` nativa, para que o tempo no
/// navegador seja contado como um app separado e possa ter a sua propria regra.
class BrowserApp extends ConsumerWidget {
  const BrowserApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Necessario para receber os avisos do lado nativo (novo endereco a abrir).
    ref.watch(nativeEventsBindingProvider);
    return MaterialApp(
      title: 'Navegador ParentaLynx',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: appLocale,
      supportedLocales: const <Locale>[appLocale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: wrapAppContent,
      home: const BrowserPage(),
    );
  }
}
