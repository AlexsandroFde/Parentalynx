import '../services/i_app_info_service.dart';

/// Versao do app instalada neste aparelho, para a aba Mais.
class GetAppVersion {
  const GetAppVersion(this._appInfo);

  final IAppInfoService _appInfo;

  /// Versao instalada, ou nulo quando o sistema nao informa.
  Future<String?> call() => _appInfo.appVersion();
}
