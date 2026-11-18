import 'package:get_it/get_it.dart';

import '../../core/platform/native_api.g.dart';
import 'data/services/native_screen_time_service.dart';
import 'domain/services/i_screen_time_service.dart';
import 'domain/usecases/get_own_time_requests.dart';
import 'domain/usecases/submit_time_request.dart';
import 'presentation/bloc/time_request_sheet/time_request_sheet_bloc.dart';

/// Registra as dependencias de tempo de tela do modo crianca: pedidos de tempo adicional
/// pelo agente nativo.
void registerScreenTimeChildModule(GetIt di) {
  di
    ..registerLazySingleton<IScreenTimeService>(() => NativeScreenTimeService(di<ChildAgentApi>()))
    ..registerFactory<SubmitTimeRequest>(() => SubmitTimeRequest(di<IScreenTimeService>()))
    ..registerFactory<GetOwnTimeRequests>(() => GetOwnTimeRequests(di<IScreenTimeService>()))
    // Uma instancia por tela inicial da crianca.
    ..registerFactory<TimeRequestSheetBloc>(
      () => TimeRequestSheetBloc(submitTimeRequest: di<SubmitTimeRequest>()),
    );
}
