import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../services/i_elevation_prompter.dart';

/// Executa uma operacao administrativa (marcada com (E) no protocolo).
///
/// Se o servidor responder que a senha precisa ser confirmada (`elevation_required`), pede a
/// senha pelo [IElevationPrompter] e repete a operacao uma vez. Se a pessoa desistir, devolve
/// [CancelledFailure], que as telas tratam em silencio.
///
/// Os casos de uso administrativos das outras funcionalidades recebem esta classe pelo
/// construtor, em vez de cada tela tratar a elevacao.
class RunElevated {
  const RunElevated(this._prompter);

  final IElevationPrompter _prompter;

  Future<Result<T>> call<T>(Future<Result<T>> Function() operation) async {
    final Result<T> first = await operation();
    if (first case Err<T>(failure: ApiFailure(isElevationRequired: true))) {
      final bool elevated = await _prompter.requestElevation();
      if (!elevated) {
        return Err<T>(const CancelledFailure());
      }
      return operation();
    }
    return first;
  }
}
