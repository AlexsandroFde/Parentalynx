/// Caminhos da area da crianca. Todos comecam com [root].
abstract final class ChildPaths {
  /// Tela de entrada, mostrada enquanto se descobre se o aparelho esta vinculado.
  static const String root = '/child';

  /// Vinculacao: codigo e espera da aprovacao.
  static const String link = '/child/link';

  /// Prefixo das telas da configuracao inicial, logo depois da vinculacao.
  static const String setupPrefix = '/child/setup/';
  static const String setupTransparency = '/child/setup/transparency';
  static const String setupPermissions = '/child/setup/permissions';

  /// Tela inicial da crianca.
  static const String home = '/child/home';

  /// O que o app controla, o que registra e o que nao ve.
  static const String about = '/child/about';

  /// Permissoes do controle, fora da configuracao inicial.
  static const String permissions = '/child/permissions';

  /// Area do responsavel neste aparelho.
  static const String guardianArea = '/child/guardian';
}
