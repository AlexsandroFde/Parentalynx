/// Regras puras do navegador gerenciado: o que o texto digitado vira e quais enderecos podem
/// ser abertos.
library;

/// Pagina vazia carregada no motor quando a pagina inicial do navegador aparece.
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
