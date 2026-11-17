import 'alert.dart';

/// Central de alertas e preferencias de notificacao (protocolo, secao 2.5).
abstract interface class AlertsRepository {
  /// Lista alertas do mais novo para o mais antigo. [before] pagina para tras e [after] traz
  /// so os mais novos que o identificador informado.
  Future<AlertsPage> list({int? after, int? before, int limit = 30, bool notifyOnly = false});

  /// Marca alertas como lidos. Devolve quantos continuam nao lidos.
  Future<int> markRead({List<int>? ids, bool all = false});

  /// Grava as preferencias de notificacao e devolve o mapa completo em vigor.
  Future<Map<String, bool>> updateNotificationPrefs(Map<String, bool> prefs);
}
