import 'package:get_it/get_it.dart';

import '../server_config/domain/usecases/watch_server_address.dart';
import '../user_role/domain/usecases/change_user_role.dart';
import 'presentation/bloc/onboarding/onboarding_bloc.dart';

/// Registra as dependencias das boas-vindas.
///
/// Depende dos modulos de perfil (gravar o papel do aparelho) e de configuracao do servidor
/// (saber se ja ha um endereco valido).
void registerOnboardingModule(GetIt di) {
  // Uma instancia por tela de boas-vindas aberta.
  di.registerFactory<OnboardingBloc>(
    () => OnboardingBloc(
      watchServerAddress: di<WatchServerAddress>(),
      changeUserRole: di<ChangeUserRole>(),
    ),
  );
}
