import '../../../../shared/domain/policy.dart';

/// Regras puras do navegador gerenciado: o que o texto digitado vira, quais enderecos podem
/// ser abertos e como explicar um bloqueio.

/// Configuracao do navegador vinda da politica.
class BrowserSettings {
  const BrowserSettings({
    required this.enabled,
    required this.logHistory,
    required this.safeSearch,
    required this.allowlistMode,
  });

  /// Falso quando o responsavel desligou o navegador ou o aparelho nao esta vinculado.
  final bool enabled;
  final bool logHistory;
  final bool safeSearch;

  /// Verdadeiro quando so os sites autorizados pelo responsavel abrem.
  final bool allowlistMode;
}

/// Decisao do filtro para uma navegacao de pagina principal.
class NavigationVerdict {
  const NavigationVerdict({required this.allowed, this.reason, this.category, this.rewrittenUrl});

  /// Bloqueio usado quando o filtro nao respondeu: na duvida, a pagina nao abre.
  const NavigationVerdict.checkFailed()
    : allowed = false,
      reason = checkFailedReason,
      category = null,
      rewrittenUrl = null;

  static const String checkFailedReason = 'check_failed';

  final bool allowed;

  /// `domain_blocked`, `category`, `safe_dns`, `not_in_allowlist` ou [checkFailedReason].
  final String? reason;
  final String? category;

  /// Endereco a carregar no lugar do pedido (busca segura), quando diferente.
  final String? rewrittenUrl;
}

/// Pagina que o filtro nao deixou abrir.
class BlockedPage {
  const BlockedPage({required this.url, this.reason, this.category});

  final String url;
  final String? reason;
  final String? category;

  /// Dominio do endereco bloqueado, para mostrar na tela.
  String get domain => Uri.tryParse(url)?.host ?? url;
}

const String blankPageUrl = 'about:blank';

const String _searchPrefix = 'https://www.google.com/search?q=';

final RegExp _domainPattern = RegExp(
  r'^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}(:\d{1,5})?([/?#].*)?$',
  caseSensitive: false,
);
final RegExp _ipPattern = RegExp(r'^\d{1,3}(\.\d{1,3}){3}(:\d{1,5})?([/?#].*)?$');
final RegExp _localhostPattern = RegExp(r'^localhost(:\d{1,5})?([/?#].*)?$', caseSensitive: false);

/// Verdadeiro para enderecos que o navegador gerenciado aceita abrir: so http e https.
bool isWebUrl(String url) {
  final Uri? uri = Uri.tryParse(url);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}

/// Converte o que a pessoa digitou na barra em um endereco para abrir.
///
/// Texto com formato de endereco vira o proprio endereco (com `https://` quando falta o
/// esquema). Qualquer outra coisa vira uma busca. Devolve nulo para texto vazio.
Uri? resolveAddressInput(String input) {
  final String text = input.trim();
  if (text.isEmpty) {
    return null;
  }
  if (!text.contains(RegExp(r'\s'))) {
    final String lower = text.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final Uri? uri = Uri.tryParse(text);
      if (uri != null && uri.host.isNotEmpty) {
        return uri;
      }
    } else if (_domainPattern.hasMatch(text)) {
      return Uri.tryParse('https://$text') ?? _search(text);
    } else if (_ipPattern.hasMatch(text) || _localhostPattern.hasMatch(text)) {
      return Uri.tryParse('http://$text') ?? _search(text);
    }
  }
  return _search(text);
}

Uri _search(String text) => Uri.parse('$_searchPrefix${Uri.encodeQueryComponent(text)}');

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
