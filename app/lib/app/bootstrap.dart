import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/bloc/app_bloc_observer.dart';
import '../core/constants/storage_keys.dart';
import '../core/logging/app_logger.dart';
import '../core/navigation/launch_action.dart';
import '../core/platform/native_api.g.dart';
import '../core/storage/secure_store.dart';
import '../features/notifications/domain/services/alert_polling_coordinator.dart';
import '../features/user_role/data/repositories/native_user_role_repository.dart';
import '../features/user_role/domain/entities/user_role.dart';
import 'config/app_config.dart';
import 'di/injection.dart';

/// Dependencias montadas e o navegador raiz, prontos para o primeiro quadro.
final class AppComposition {
  const AppComposition({required this.di, required this.navigatorKey});

  final GetIt di;
  final GlobalKey<NavigatorState> navigatorKey;
}

/// Prepara o que precisa existir antes do primeiro quadro: localizacao de datas, observador
/// dos BLoCs, perfil, endereco do servidor e token de sessao gravados, e o conteiner de
/// dependencias.
Future<AppComposition> bootstrap() async {
  await _prepareEngine();

  final UserRole role = await NativeUserRoleRepository.readInitial(AppModeApi());
  final SecureStore store = NativeSecureStore(SecureStorageApi());
  String serverUrl = AppConfig.defaultServerUrl;
  String? sessionToken;
  try {
    serverUrl = await store.read(StorageKeys.serverUrl) ?? AppConfig.defaultServerUrl;
    if (role == UserRole.guardian) {
      sessionToken = await store.read(StorageKeys.guardianSessionToken);
    }
  } on PlatformException {
    // A ponte nativa nao respondeu. O app sobe com os valores padrao e a tela de boas-vindas
    // deixa a pessoa tentar de novo.
  }

  final GetIt di = GetIt.instance;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  configureDependencies(
    di,
    values: AppBootValues(role: role, serverUrl: serverUrl, sessionToken: sessionToken),
    navigatorKey: navigatorKey,
  );

  // Passa a receber as acoes de abertura (notificacao, tela de bloqueio) desde ja, para nao
  // perder uma acao que chegue antes da primeira tela.
  di<LaunchActionSource>();
  // Liga e desliga a busca de alertas em segundo plano conforme a sessao do responsavel.
  di<AlertPollingCoordinator>().start();

  return AppComposition(di: di, navigatorKey: navigatorKey);
}

/// Prepara o motor do navegador gerenciado, que roda separado do app principal: so o nucleo e
/// o modulo do navegador.
Future<GetIt> bootstrapBrowser() async {
  await _prepareEngine();
  final GetIt di = GetIt.instance;
  configureBrowserDependencies(di);
  return di;
}

/// O que todo motor Flutter do app precisa antes do primeiro quadro: a ligacao com a
/// plataforma, a localizacao de datas e o observador dos BLoCs.
Future<void> _prepareEngine() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  Intl.defaultLocale = 'pt_BR';
  Bloc.observer = const AppBlocObserver(
    DeveloperLogger(),
    logTransitions: !AppConfig.isReleaseBuild,
  );
}
