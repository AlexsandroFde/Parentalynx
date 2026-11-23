/// Configuracao do app definida no codigo.
///
/// So a camada de composicao (`app/`) le esta classe: as funcionalidades recebem os valores
/// de que precisam pela injecao de dependencias.
abstract final class AppConfig {
  /// Endereco do servidor ParentaLynx. E fixo: o app nao oferece a troca.
  ///
  /// Enquanto o dominio nao existe, aponta para o servidor local visto de dentro do emulador
  /// Android. Com o servidor no VPS, troque por `https://api.SEU_DOMINIO`: o build de
  /// producao so fala HTTPS (ver docs/08-servidor-vps.md).
  static const String serverUrl = 'http://10.0.2.2:8080';

  static const bool isReleaseBuild = bool.fromEnvironment('dart.vm.product');
}
