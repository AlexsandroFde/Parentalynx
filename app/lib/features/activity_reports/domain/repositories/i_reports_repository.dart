import '../../../../core/result/result.dart';
import '../entities/browsing_entry.dart';
import '../entities/cursor_page.dart';
import '../entities/device_event.dart';
import '../entities/report_summary.dart';
import '../entities/usage_session.dart';

/// Relatorios de uso dos aparelhos (protocolo, secoes 4 e 6).
abstract interface class IReportsRepository {
  /// Resumo do intervalo de dias da cota `[from, to]`.
  Future<Result<ReportSummary>> summary(
    String deviceId, {
    required String from,
    required String to,
  });

  /// Sessoes de uso de um dia da cota.
  Future<Result<List<UsageSession>>> sessions(String deviceId, {required String day});

  /// Eventos do periodo, do mais recente para o mais antigo. [types] vazio traz todos.
  Future<Result<CursorPage<DeviceEvent>>> events(
    String deviceId, {
    required String from,
    required String to,
    List<String> types = const <String>[],
    String? before,
    int limit = 50,
  });

  /// Historico do navegador gerenciado no periodo, do mais recente para o mais antigo.
  Future<Result<CursorPage<BrowsingEntry>>> browsing(
    String deviceId, {
    required String from,
    required String to,
    String? before,
    int limit = 50,
  });
}
