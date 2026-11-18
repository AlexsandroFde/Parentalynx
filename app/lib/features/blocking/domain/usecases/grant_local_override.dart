import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../services/i_application_blocking_service.dart';

/// O responsavel libera o uso deste aparelho por alguns minutos (area do responsavel).
///
/// Funciona sem internet: o agente nativo confere a autenticacao local do responsavel e
/// registra a liberacao.
class GrantLocalOverride {
  const GrantLocalOverride(this._service);

  /// Opcoes oferecidas ao responsavel, em minutos.
  static const List<int> options = <int>[15, 30, 60];

  final IApplicationBlockingService _service;

  Future<Result<void>> call(int minutes) async {
    if (minutes <= 0) {
      return const Err<void>(ValidationFailure('Escolha por quanto tempo liberar o uso.'));
    }
    return _service.grantLocalOverride(minutes);
  }
}
