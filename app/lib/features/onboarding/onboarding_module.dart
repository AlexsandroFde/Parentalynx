import 'package:get_it/get_it.dart';

import '../user_role/domain/usecases/change_user_role.dart';
import 'presentation/bloc/onboarding/onboarding_bloc.dart';

/// Registra as dependencias das boas-vindas.
///
/// Depende do modulo de perfil (gravar o papel do aparelho).
void registerOnboardingModule(GetIt di) {
  // Uma instancia por tela de boas-vindas aberta.
  di.registerFactory<OnboardingBloc>(() => OnboardingBloc(changeUserRole: di<ChangeUserRole>()));
}
