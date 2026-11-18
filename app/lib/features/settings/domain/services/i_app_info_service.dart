/// Informacoes do app instalado neste aparelho.
abstract interface class IAppInfoService {
  /// Versao instalada, ou nulo quando o sistema nao informa.
  Future<String?> appVersion();
}
