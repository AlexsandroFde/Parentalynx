import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../core/config/app_config.dart';
import '../core/network/network_providers.dart';
import '../core/platform/native_api.g.dart';
import '../core/platform/native_providers.dart';
import '../core/storage/secure_store.dart';

/// Prepara o que precisa existir antes do primeiro quadro: localizacao de datas, modo do app,
/// endereco do servidor e token de sessao. Devolve o conteiner de provedores ja preenchido.
Future<ProviderContainer> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  Intl.defaultLocale = 'pt_BR';

  final SecureStore store = NativeSecureStore(SecureStorageApi());
  AppMode mode = AppMode.unset;
  String serverUrl = AppConfig.defaultServerUrl;
  String? sessionToken;
  try {
    mode = await AppModeApi().getMode();
    serverUrl = await store.read(StorageKeys.serverUrl) ?? AppConfig.defaultServerUrl;
    if (mode == AppMode.guardian) {
      sessionToken = await store.read(StorageKeys.guardianSessionToken);
    }
  } on PlatformException {
    // A ponte nativa nao respondeu. O app sobe sem modo definido e a tela de boas-vindas
    // deixa a pessoa tentar de novo.
  }

  return ProviderContainer(
    overrides: [
      initialAppModeProvider.overrideWithValue(mode),
      initialServerUrlProvider.overrideWithValue(serverUrl),
      initialSessionTokenProvider.overrideWithValue(sessionToken),
    ],
  );
}
