/// Regra dos enderecos de servidor aceitos.
///
/// Em producao so HTTPS e aceito. Em depuracao aceita HTTP, para testes em rede local. Quem
/// decide e a configuracao do build, entregue pela injecao de dependencias.
final class ServerAddressPolicy {
  const ServerAddressPolicy({required this.allowInsecureHttp});

  final bool allowInsecureHttp;

  bool accepts(String url) {
    final Uri? uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return false;
    }
    if (uri.scheme == 'https') {
      return true;
    }
    return uri.scheme == 'http' && allowInsecureHttp;
  }

  /// Explica o formato esperado quando o endereco e recusado.
  String get requirementMessage {
    return allowInsecureHttp
        ? 'Informe um endereço completo, por exemplo https://controle.exemplo.com'
        : 'Informe um endereço completo que comece com https://';
  }
}
