/// Textos do navegador gerenciado.
library;

import '../../../device_policy/domain/entities/policy.dart';
import '../../domain/entities/navigation_verdict.dart';
import '../../domain/services/browser_navigation_rules.dart';

const String unsupportedAddressNotice = 'Este tipo de endereço não abre no navegador seguro.';

const String unsupportedLinkNotice = 'Este tipo de link não abre no navegador seguro.';

const String pageLoadErrorMessage =
    'Não foi possível abrir esta página. Confira a internet e tente de novo.';

/// Texto curto do endereco para a barra quando ela nao esta em edicao: sem esquema e sem
/// `www.`.
String displayAddress(String url) {
  if (url.isEmpty || url == blankPageUrl) {
    return '';
  }
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) {
    return url;
  }
  final String host = uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
  final String path = uri.path == '/' ? '' : uri.path;
  return '$host$path';
}

/// Explicacao de um bloqueio, em linguagem simples.
String blockedReasonText(String? reason, String? category) {
  switch (reason) {
    case 'domain_blocked':
      return 'O seu responsável bloqueou este site.';
    case 'category':
      final WebCategory? known = category == null ? null : WebCategory.fromCode(category);
      return known == null
          ? 'Este site é de um tipo que o seu responsável bloqueou.'
          : 'Este site é de um tipo que o seu responsável bloqueou: '
                '${known.label.toLowerCase()}.';
    case 'safe_dns':
      return 'O filtro de segurança barrou este site. Ele pode ter conteúdo adulto ou perigoso.';
    case 'not_in_allowlist':
      return 'Neste navegador só abrem os sites que o seu responsável escolheu.';
    case NavigationVerdict.checkFailedReason:
      return 'Não foi possível conferir se este site é liberado. Tente de novo daqui a pouco.';
    default:
      return 'Este site não pode ser aberto neste navegador.';
  }
}
