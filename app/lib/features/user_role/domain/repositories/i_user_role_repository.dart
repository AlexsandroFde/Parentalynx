import '../../../../core/result/result.dart';
import '../entities/user_role.dart';

/// Perfil gravado neste aparelho.
///
/// O lado nativo guarda o perfil e recusa sair do perfil crianca enquanto o aparelho estiver
/// vinculado (a desvinculacao exige o responsavel).
abstract interface class IUserRoleRepository {
  /// Perfil atual.
  UserRole get current;

  /// Perfil atual seguido das trocas.
  Stream<UserRole> watch();

  /// Troca o perfil. Falha com `NativeFailure` (`modeLocked`) quando o lado nativo recusa.
  Future<Result<void>> change(UserRole role);
}
