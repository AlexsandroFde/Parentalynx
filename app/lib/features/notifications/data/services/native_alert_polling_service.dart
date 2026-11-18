import '../../../../core/network/server_endpoint.dart';
import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../domain/services/i_alert_polling_service.dart';

/// Busca de alertas em segundo plano pelo worker nativo ([GuardianNativeApi]).
///
/// O worker le o token da sessao no armazenamento seguro; aqui so vai o endereco do servidor.
/// Falhas da ponte sao ignoradas: a busca e um reforco dos alertas em tempo real.
class NativeAlertPollingService implements IAlertPollingService {
  const NativeAlertPollingService({required this._api, required this._endpoint});

  final GuardianNativeApi _api;
  final ServerEndpoint _endpoint;

  @override
  Future<void> enable() => callNativeOr<void>(() => _api.enableAlertPolling(_endpoint.url), null);

  @override
  Future<void> disable() => callNativeOr<void>(_api.disableAlertPolling, null);

  @override
  Future<void> markSeen(int alertId) {
    // No pior caso um alerta ja visto gera tambem uma notificacao.
    return callNativeOr<void>(() => _api.setLastSeenAlertId(alertId), null);
  }
}
