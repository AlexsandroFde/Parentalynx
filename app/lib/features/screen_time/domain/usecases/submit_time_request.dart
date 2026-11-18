import '../../../../core/result/result.dart';
import '../services/i_screen_time_service.dart';

/// A crianca pede mais tempo ao responsavel, com um recado opcional.
///
/// O pedido entra na fila do agente nativo e chega ao responsavel quando houver conexao.
class SubmitTimeRequest {
  const SubmitTimeRequest(this._service);

  final IScreenTimeService _service;

  /// Devolve o identificador do pedido.
  Future<Result<String>> call({required int minutes, String? message}) {
    final String text = message?.trim() ?? '';
    return _service.submitTimeRequest(minutes: minutes, message: text.isEmpty ? null : text);
  }
}
