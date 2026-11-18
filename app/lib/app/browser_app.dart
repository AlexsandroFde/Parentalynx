import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';

import '../features/managed_browser/presentation/bloc/browser_bloc.dart';
import '../features/managed_browser/presentation/engine/browser_engine.dart';
import '../features/managed_browser/presentation/pages/browser_page.dart';
import '../shared/design_system/design_system.dart';
import '../shared/theme/app_frame.dart';

/// Raiz do navegador gerenciado, executada pelo ponto de entrada `browserMain`.
///
/// Roda em um motor Flutter proprio, dentro da `BrowserActivity` nativa, para que o tempo no
/// navegador seja contado como um app separado e possa ter a sua propria regra. [di] precisa
/// ter o nucleo e o modulo do navegador (`registerManagedBrowserModule`) registrados.
class BrowserApp extends StatelessWidget {
  const BrowserApp({required this.di, super.key});

  final GetIt di;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<BrowserEngine>(
      create: (BuildContext context) => di<BrowserEngine>(),
      child: BlocProvider<BrowserBloc>(
        create: (BuildContext context) {
          return di<BrowserBloc>(param1: context.read<BrowserEngine>())
            ..add(const BrowserStarted());
        },
        child: MaterialApp(
          title: 'Navegador ParentaLynx',
          debugShowCheckedModeBanner: false,
          // O navegador e usado pela crianca: perfil infantil do Design System.
          theme: AppTheme.light(experience: AppExperience.child),
          darkTheme: AppTheme.dark(experience: AppExperience.child),
          locale: appLocale,
          supportedLocales: const <Locale>[appLocale],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: wrapAppContent,
          home: const BrowserPage(),
        ),
      ),
    );
  }
}
