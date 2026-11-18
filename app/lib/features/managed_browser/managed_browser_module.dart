import 'package:get_it/get_it.dart';

import '../../core/platform/native_api.g.dart';
import '../../core/platform/native_events.dart';
import 'data/services/native_browser_url_requests.dart';
import 'data/services/native_managed_browser_launcher.dart';
import 'data/services/native_web_filter_service.dart';
import 'domain/services/i_browser_url_requests.dart';
import 'domain/services/i_managed_browser_launcher.dart';
import 'domain/services/i_web_filter_service.dart';
import 'domain/usecases/evaluate_navigation.dart';
import 'domain/usecases/get_browser_settings.dart';
import 'domain/usecases/open_managed_browser.dart';
import 'domain/usecases/record_browser_visit.dart';
import 'domain/usecases/watch_browser_url_requests.dart';
import 'presentation/bloc/browser_bloc.dart';
import 'presentation/engine/browser_engine.dart';
import 'presentation/engine/webview_browser_engine.dart';

/// Registra o navegador gerenciado: filtro e historico (agente nativo), enderecos pedidos
/// por outros apps, motor de paginas e o BLoC da tela.
///
/// Usado pelos dois motores Flutter: o do navegador (`browserMain`), que monta o
/// `BrowserApp`, e o do app principal, em que o modo crianca so usa [OpenManagedBrowser].
void registerManagedBrowserModule(GetIt di) {
  // Dados.
  di
    ..registerLazySingleton<IWebFilterService>(() => NativeWebFilterService(di<BrowserApi>()))
    ..registerLazySingleton<IBrowserUrlRequests>(
      () => NativeBrowserUrlRequests(api: di<BrowserApi>(), events: di<NativeEventsDispatcher>()),
    )
    ..registerLazySingleton<IManagedBrowserLauncher>(
      () => NativeManagedBrowserLauncher(di<ChildAgentApi>()),
    );

  // Casos de uso.
  di
    ..registerFactory<GetBrowserSettings>(() => GetBrowserSettings(di<IWebFilterService>()))
    ..registerFactory<EvaluateNavigation>(() => EvaluateNavigation(di<IWebFilterService>()))
    ..registerFactory<RecordBrowserVisit>(() => RecordBrowserVisit(di<IWebFilterService>()))
    ..registerFactory<WatchBrowserUrlRequests>(
      () => WatchBrowserUrlRequests(di<IBrowserUrlRequests>()),
    )
    ..registerFactory<OpenManagedBrowser>(() => OpenManagedBrowser(di<IManagedBrowserLauncher>()));

  // Apresentacao. O motor e trocado nos testes, porque o WebView so funciona em um aparelho.
  di
    ..registerFactory<BrowserEngine>(WebViewBrowserEngine.new)
    ..registerFactoryParam<BrowserBloc, BrowserEngine, void>(
      (BrowserEngine engine, void _) => BrowserBloc(
        engine: engine,
        getBrowserSettings: di<GetBrowserSettings>(),
        evaluateNavigation: di<EvaluateNavigation>(),
        recordBrowserVisit: di<RecordBrowserVisit>(),
        watchBrowserUrlRequests: di<WatchBrowserUrlRequests>(),
      ),
    );
}
