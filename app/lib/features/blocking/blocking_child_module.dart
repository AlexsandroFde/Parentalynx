import 'package:get_it/get_it.dart';

import '../../core/platform/native_api.g.dart';
import 'data/services/native_application_blocking_service.dart';
import 'domain/services/i_application_blocking_service.dart';
import 'domain/usecases/clear_local_override.dart';
import 'domain/usecases/grant_local_override.dart';

/// Registra as dependencias de bloqueio do modo crianca: liberacao local concedida pelo
/// responsavel no proprio aparelho.
void registerBlockingChildModule(GetIt di) {
  di
    ..registerLazySingleton<IApplicationBlockingService>(
      () => NativeApplicationBlockingService(di<ChildAgentApi>()),
    )
    ..registerFactory<GrantLocalOverride>(
      () => GrantLocalOverride(di<IApplicationBlockingService>()),
    )
    ..registerFactory<ClearLocalOverride>(
      () => ClearLocalOverride(di<IApplicationBlockingService>()),
    );
}
