/// Endereco do servidor ParentaLynx, sem barra no final.
///
/// O valor vem do codigo (`AppConfig.serverUrl`) e nao muda durante o uso. Fica num objeto
/// proprio para as funcionalidades e os testes o receberem pela injecao de dependencias.
class ServerEndpoint {
  ServerEndpoint(String url) : url = normalize(url);

  final String url;

  static String normalize(String url) {
    final String trimmed = url.trim();
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }
}
