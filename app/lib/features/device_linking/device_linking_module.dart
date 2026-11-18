import 'package:get_it/get_it.dart';

import '../../core/network/api_client.dart';
import '../../core/time/clock.dart';
import '../authentication/domain/usecases/run_elevated.dart';
import '../child_device/domain/repositories/i_child_device_repository.dart';
import '../device_sync/domain/usecases/watch_realtime_updates.dart';
import 'data/datasources/remote/guardian_linking_remote_data_source.dart';
import 'data/repositories/api_guardian_linking_repository.dart';
import 'domain/repositories/i_guardian_linking_repository.dart';
import 'domain/usecases/approve_link_request.dart';
import 'domain/usecases/cancel_link_code.dart';
import 'domain/usecases/check_link_requests.dart';
import 'domain/usecases/expire_link_code.dart';
import 'domain/usecases/generate_link_code.dart';
import 'domain/usecases/get_shown_link_code.dart';
import 'domain/usecases/reject_link_request.dart';
import 'presentation/bloc/device_linking/device_linking_bloc.dart';

/// Registra as dependencias da vinculacao vista pelo responsavel: codigo, pedidos, aprovacao e
/// rejeicao. O lado da crianca e registrado por `registerDeviceLinkingChildModule`.
///
/// Depende dos modulos de autenticacao (elevacao), aparelhos (lista de aparelhos) e
/// sincronizacao (avisos em tempo real).
void registerDeviceLinkingModule(GetIt di) {
  // Dados. O repositorio vive enquanto o app vive: guarda o ultimo codigo gerado.
  di
    ..registerLazySingleton<GuardianLinkingRemoteDataSource>(
      () => GuardianLinkingRemoteDataSource(di<ApiClient>()),
    )
    ..registerLazySingleton<IGuardianLinkingRepository>(
      () => ApiGuardianLinkingRepository(di<GuardianLinkingRemoteDataSource>()),
    );

  // Casos de uso.
  di
    ..registerFactory<GetShownLinkCode>(() => GetShownLinkCode(di<IGuardianLinkingRepository>()))
    ..registerFactory<GenerateLinkCode>(
      () => GenerateLinkCode(
        repository: di<IGuardianLinkingRepository>(),
        runElevated: di<RunElevated>(),
      ),
    )
    ..registerFactory<CancelLinkCode>(() => CancelLinkCode(di<IGuardianLinkingRepository>()))
    ..registerFactory<ExpireLinkCode>(() => ExpireLinkCode(di<IGuardianLinkingRepository>()))
    ..registerFactory<CheckLinkRequests>(
      () => CheckLinkRequests(
        repository: di<IGuardianLinkingRepository>(),
        devices: di<IChildDeviceRepository>(),
      ),
    )
    ..registerFactory<ApproveLinkRequest>(
      () => ApproveLinkRequest(
        repository: di<IGuardianLinkingRepository>(),
        devices: di<IChildDeviceRepository>(),
        runElevated: di<RunElevated>(),
      ),
    )
    ..registerFactory<RejectLinkRequest>(
      () => RejectLinkRequest(
        repository: di<IGuardianLinkingRepository>(),
        devices: di<IChildDeviceRepository>(),
      ),
    );

  // Apresentacao: um por tela de vinculacao aberta.
  di.registerFactory<DeviceLinkingBloc>(
    () => DeviceLinkingBloc(
      getShownCode: di<GetShownLinkCode>(),
      checkRequests: di<CheckLinkRequests>(),
      generateCode: di<GenerateLinkCode>(),
      cancelCode: di<CancelLinkCode>(),
      expireCode: di<ExpireLinkCode>(),
      approve: di<ApproveLinkRequest>(),
      reject: di<RejectLinkRequest>(),
      watchRealtimeUpdates: di<WatchRealtimeUpdates>(),
      clock: di<Clock>(),
    ),
  );
}
