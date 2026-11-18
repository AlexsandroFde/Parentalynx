/// Configuracao definida no momento do build.
///
/// So a camada de composicao (`app/`) le esta classe: as funcionalidades recebem os valores
/// de que precisam pela injecao de dependencias (por exemplo a regra de enderecos aceitos).
///
/// O endereco do servidor vem de `--dart-define=API_BASE_URL=https://...`. Em build de
/// depuracao, se nada for informado, usa o servidor local visto de dentro do emulador.
abstract final class AppConfig {
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const bool isReleaseBuild = bool.fromEnvironment('dart.vm.product');

  /// Endereco padrao do servidor, ou vazio quando o build de producao nao trouxe um.
  static String get defaultServerUrl {
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }
    return isReleaseBuild ? '' : 'http://10.0.2.2:8080';
  }

  /// So builds de depuracao aceitam servidor sem TLS (testes em rede local).
  static bool get allowInsecureHttp => !isReleaseBuild;
}
