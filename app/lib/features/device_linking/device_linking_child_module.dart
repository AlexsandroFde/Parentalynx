import 'package:get_it/get_it.dart';

import '../../core/network/api_client.dart';
import '../../core/network/server_endpoint.dart';
import '../../core/platform/native_api.g.dart';
import '../../core/storage/secure_store.dart';
import '../user_role/domain/usecases/change_user_role.dart';
import 'data/datasources/local/pending_claim_local_data_source.dart';
import 'data/datasources/remote/pairing_claim_remote_data_source.dart';
import 'data/repositories/api_pairing_claim_repository.dart';
import 'data/repositories/link_state_repository.dart';
import 'data/repositories/secure_pending_claim_store.dart';
import 'data/services/native_device_activation_service.dart';
import 'data/services/native_device_identity_service.dart';
import 'domain/repositories/i_link_state_repository.dart';
import 'domain/repositories/i_pairing_claim_repository.dart';
import 'domain/repositories/i_pending_claim_store.dart';
import 'domain/services/i_device_activation_service.dart';
import 'domain/services/i_device_identity_service.dart';
import 'domain/usecases/activate_linked_device.dart';
import 'domain/usecases/check_pairing_status.dart';
import 'domain/usecases/discard_pending_claim.dart';
import 'domain/usecases/finish_link_onboarding.dart';
import 'domain/usecases/get_device_identity.dart';
import 'domain/usecases/report_agent_inactive.dart';
import 'domain/usecases/resolve_link_state.dart';
import 'domain/usecases/restore_pending_claim.dart';
import 'domain/usecases/submit_pairing_code.dart';
import 'domain/usecases/unlink_this_device.dart';
import 'domain/usecases/watch_link_state.dart';
import 'presentation/bloc/child_link/child_link_bloc.dart';
import 'presentation/bloc/child_linking/child_linking_bloc.dart';

/// Registra as dependencias da vinculacao no aparelho da crianca: pedido com o codigo,
/// espera da aprovacao, ativacao do agente e situacao do vinculo.
void registerDeviceLinkingChildModule(GetIt di) {
  // Dados.
  di
    ..registerLazySingleton<PairingClaimRemoteDataSource>(
      () => PairingClaimRemoteDataSource(di<ApiClient>()),
    )
    ..registerLazySingleton<PendingClaimLocalDataSource>(
      () => PendingClaimLocalDataSource(di<SecureStore>()),
    )
    ..registerLazySingleton<IPairingClaimRepository>(
      () => ApiPairingClaimRepository(di<PairingClaimRemoteDataSource>()),
    )
    ..registerLazySingleton<IPendingClaimStore>(
      () => SecurePendingClaimStore(di<PendingClaimLocalDataSource>()),
    )
    // Fonte unica de verdade da fase do vinculo.
    ..registerLazySingleton<ILinkStateRepository>(LinkStateRepository.new)
    ..registerLazySingleton<IDeviceIdentityService>(
      () => NativeDeviceIdentityService(di<DeviceApi>()),
    )
    ..registerLazySingleton<IDeviceActivationService>(
      () => NativeDeviceActivationService(api: di<ChildAgentApi>(), endpoint: di<ServerEndpoint>()),
    );

  // Casos de uso.
  di
    ..registerFactory<GetDeviceIdentity>(() => GetDeviceIdentity(di<IDeviceIdentityService>()))
    ..registerFactory<SubmitPairingCode>(
      () => SubmitPairingCode(
        claims: di<IPairingClaimRepository>(),
        store: di<IPendingClaimStore>(),
        identity: di<IDeviceIdentityService>(),
      ),
    )
    ..registerFactory<CheckPairingStatus>(() => CheckPairingStatus(di<IPairingClaimRepository>()))
    ..registerFactory<ActivateLinkedDevice>(
      () => ActivateLinkedDevice(
        activation: di<IDeviceActivationService>(),
        store: di<IPendingClaimStore>(),
        linkState: di<ILinkStateRepository>(),
      ),
    )
    ..registerFactory<RestorePendingClaim>(() => RestorePendingClaim(di<IPendingClaimStore>()))
    ..registerFactory<DiscardPendingClaim>(() => DiscardPendingClaim(di<IPendingClaimStore>()))
    ..registerFactory<WatchLinkState>(() => WatchLinkState(di<ILinkStateRepository>()))
    ..registerFactory<ResolveLinkState>(
      () => ResolveLinkState(
        activation: di<IDeviceActivationService>(),
        linkState: di<ILinkStateRepository>(),
      ),
    )
    ..registerFactory<FinishLinkOnboarding>(() => FinishLinkOnboarding(di<ILinkStateRepository>()))
    ..registerFactory<ReportAgentInactive>(() => ReportAgentInactive(di<ILinkStateRepository>()))
    ..registerFactory<UnlinkThisDevice>(
      () => UnlinkThisDevice(
        activation: di<IDeviceActivationService>(),
        linkState: di<ILinkStateRepository>(),
        changeUserRole: di<ChangeUserRole>(),
      ),
    );

  // Apresentacao.
  di
    // Vive enquanto o app vive: o roteador observa a fase do vinculo no modo crianca.
    ..registerLazySingleton<ChildLinkBloc>(
      () => ChildLinkBloc(
        watchLinkState: di<WatchLinkState>(),
        resolveLinkState: di<ResolveLinkState>(),
      )..add(const ChildLinkSubscriptionRequested()),
      dispose: (ChildLinkBloc bloc) => bloc.close(),
    )
    // Uma instancia por tela do codigo aberta.
    ..registerFactory<ChildLinkingBloc>(
      () => ChildLinkingBloc(
        getDeviceIdentity: di<GetDeviceIdentity>(),
        submitPairingCode: di<SubmitPairingCode>(),
        checkPairingStatus: di<CheckPairingStatus>(),
        activateLinkedDevice: di<ActivateLinkedDevice>(),
        restorePendingClaim: di<RestorePendingClaim>(),
        discardPendingClaim: di<DiscardPendingClaim>(),
        changeUserRole: di<ChangeUserRole>(),
      ),
    );
}
