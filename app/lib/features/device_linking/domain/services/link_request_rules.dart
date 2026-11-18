import '../../../child_device/domain/services/child_name_policy.dart';
import '../entities/link_request.dart';

/// Regras da vinculacao vista pelo responsavel. Funcoes puras.
abstract final class LinkRequestRules {
  /// Validade padrao de um codigo de vinculacao (protocolo, secao 3.1).
  static const Duration codeLifetime = Duration(minutes: 15);

  /// Mensagem de erro do nome da crianca ao aprovar, ou nulo quando e aceito.
  static String? childNameError(String name) {
    final String clean = name.trim();
    if (clean.isEmpty) {
      return 'Informe o nome da criança.';
    }
    if (clean.length > ChildNamePolicy.maxLength) {
      return 'Use no máximo ${ChildNamePolicy.maxLength} caracteres.';
    }
    return null;
  }

  /// Verdadeiro quando as duas listas tem os mesmos pedidos, em qualquer ordem.
  static bool sameRequests(List<LinkRequest> a, List<LinkRequest> b) {
    if (a.length != b.length) {
      return false;
    }
    final Set<String> ids = a.map((LinkRequest request) => request.id).toSet();
    return b.every((LinkRequest request) => ids.contains(request.id));
  }
}
