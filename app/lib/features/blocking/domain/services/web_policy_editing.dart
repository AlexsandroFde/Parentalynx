import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../device_policy/domain/entities/policy.dart';

/// Listas de sites da politica de navegacao.
enum WebDomainList {
  /// Sites bloqueados (modo lista de bloqueio).
  blocked,

  /// Sites autorizados (modo so autorizados).
  allowed;

  List<String> read(WebPolicy web) {
    return switch (this) {
      WebDomainList.blocked => web.blockedDomains,
      WebDomainList.allowed => web.allowedDomains,
    };
  }

  WebPolicy write(WebPolicy web, List<String> domains) {
    return switch (this) {
      WebDomainList.blocked => web.copyWith(blockedDomains: domains),
      WebDomainList.allowed => web.copyWith(allowedDomains: domains),
    };
  }
}

/// Regras de edicao da politica de navegacao. Funcoes puras.
abstract final class WebPolicyEditing {
  /// Quantos sites cada lista aceita.
  static const int maxDomains = 500;

  /// Confere um endereco digitado para entrar em uma lista. Devolve o dominio limpo, ou a
  /// explicacao do que corrigir.
  static Result<String> validateNewDomain(List<String> domains, String input) {
    final String? domain = WebPolicy.normalizeDomain(input);
    if (domain == null) {
      return const Err<String>(
        ValidationFailure('Digite um endereço válido, por exemplo exemplo.com.br'),
      );
    }
    if (domains.contains(domain)) {
      return const Err<String>(ValidationFailure('Esse site já está na lista.'));
    }
    if (domains.length >= maxDomains) {
      return const Err<String>(ValidationFailure('A lista chegou ao limite de $maxDomains sites.'));
    }
    return Ok<String>(domain);
  }

  /// Acrescenta um dominio ja conferido a uma lista.
  static WebPolicy addDomain(WebPolicy web, WebDomainList list, String domain) {
    final List<String> current = list.read(web);
    if (current.contains(domain) || current.length >= maxDomains) {
      return web;
    }
    return list.write(web, <String>[...current, domain]);
  }

  static WebPolicy removeDomain(WebPolicy web, WebDomainList list, String domain) {
    return list.write(web, list.read(web).where((String item) => item != domain).toList());
  }

  /// Bloqueia ou libera uma categoria de sites.
  static WebPolicy withCategory(WebPolicy web, WebCategory category, {required bool blocked}) {
    final List<String> next = <String>[...web.blockedCategories]..remove(category.code);
    if (blocked) {
      next.add(category.code);
    }
    return web.copyWith(blockedCategories: next);
  }
}
