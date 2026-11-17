/// Configuracao definida no momento do build.
///
/// O endereco do servidor vem de `--dart-define=API_BASE_URL=https://...`. Em build de
/// depuracao, se nada for informado, usa o servidor local visto de dentro do emulador.
abstract final class AppConfig {
  static const String appName = 'ParentaLynx';

  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const bool isReleaseBuild = bool.fromEnvironment('dart.vm.product');

  /// Endereco padrao do servidor, ou vazio quando o build de producao nao trouxe um.
  static String get defaultServerUrl {
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }
    return isReleaseBuild ? '' : 'http://10.0.2.2:8080';
  }

  /// Em producao so se aceita HTTPS. Em depuracao aceita HTTP para testes em rede local.
  static bool isAcceptableServerUrl(String url) {
    final Uri? uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return false;
    }
    if (uri.scheme == 'https') {
      return true;
    }
    return uri.scheme == 'http' && !isReleaseBuild;
  }

  /// Pacote virtual que representa o navegador gerenciado na politica e nos relatorios.
  static const String browserPackage = 'com.parentalynx.app.browser';
}

/// Chaves do armazenamento seguro usadas pelo lado Dart.
///
/// O prefixo `agent.` e reservado ao agente nativo e nao pode ser lido daqui.
abstract final class StorageKeys {
  static const String serverUrl = 'config.server_url';

  /// Lida tambem pelo worker nativo de alertas. Nao renomear sem alterar o Kotlin.
  static const String guardianSessionToken = 'guardian.session_token';
  static const String guardianSessionId = 'guardian.session_id';
  static const String guardianEmail = 'guardian.email';
}
