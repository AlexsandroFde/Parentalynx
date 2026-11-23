/// Configuracao do app definida no codigo.
///
/// So a camada de composicao (`app/`) le esta classe: as funcionalidades recebem os valores
/// de que precisam pela injecao de dependencias.
abstract final class AppConfig {
  /// Endereco do servidor ParentaLynx (VM na Oracle Cloud). E fixo: o app nao oferece a troca.
  ///
  /// Para testar contra o servidor local no emulador Android, troque temporariamente por
  /// `http://10.0.2.2:8080`. O build de producao so fala HTTPS (ver docs/08-servidor-vps.md).
  static const String serverUrl = 'https://parentalynx.ddns.net';

  static const bool isReleaseBuild = bool.fromEnvironment('dart.vm.product');
}
