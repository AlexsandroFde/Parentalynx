import '../../../../core/result/result.dart';
import '../entities/policy.dart';

/// Politica em vigor neste aparelho (modo crianca), mantida pelo agente nativo.
///
/// Quem aplica as regras e o agente nativo, com ou sem a interface aberta. O Flutter so le a
/// politica para mostrar a crianca o que vale.
abstract interface class IDevicePolicyService {
  /// Politica aplicada, ou nulo quando o agente ainda nao tem politica (ou ela nao pode ser
  /// lida).
  Future<Result<Policy?>> activePolicy();
}
