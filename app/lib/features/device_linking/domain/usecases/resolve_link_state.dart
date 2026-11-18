import '../../../../core/result/result.dart';
import '../entities/link_state.dart';
import '../repositories/i_link_state_repository.dart';
import '../services/i_device_activation_service.dart';

/// Descobre se este aparelho esta vinculado, perguntando ao agente nativo.
///
/// So consulta enquanto a fase e desconhecida (ou falhou e a pessoa pediu para tentar de
/// novo). Um vinculo concluido enquanto a consulta estava em andamento tem prioridade sobre a
/// resposta.
class ResolveLinkState {
  const ResolveLinkState({required this._activation, required this._linkState});

  final IDeviceActivationService _activation;
  final ILinkStateRepository _linkState;

  Future<void> call() async {
    if (_linkState.current.phase == LinkPhase.failed) {
      _linkState.update(LinkState.initial);
    }
    if (_linkState.current.phase != LinkPhase.unknown) {
      return;
    }
    final Result<bool> active = await _activation.isActivated();
    if (_linkState.current.phase != LinkPhase.unknown) {
      return;
    }
    _linkState.update(
      LinkState(
        active.fold(
          onOk: (bool value) => value ? LinkPhase.ready : LinkPhase.unlinked,
          onErr: (_) => LinkPhase.failed,
        ),
      ),
    );
  }
}
