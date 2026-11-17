import '../../../../core/json/json_reader.dart';
import '../../../../shared/domain/policy.dart';

/// Categoria de um app, como o aparelho a identifica (protocolo, secao 5.1).
enum AppCategory {
  games('games', 'Jogos'),
  social('social', 'Redes sociais'),
  video('video', 'Vídeo'),
  audio('audio', 'Música e áudio'),
  image('image', 'Fotos e imagens'),
  news('news', 'Notícias'),
  maps('maps', 'Mapas'),
  productivity('productivity', 'Produtividade'),
  communication('communication', 'Comunicação'),
  browser('browser', 'Navegadores'),
  system('system', 'Sistema'),
  other('other', 'Outros');

  const AppCategory(this.code, this.label);

  final String code;
  final String label;

  static AppCategory parse(String? code) {
    for (final AppCategory category in values) {
      if (category.code == code) {
        return category;
      }
    }
    return AppCategory.other;
  }
}

/// App do inventario do aparelho visto pelo responsavel (protocolo, secao 5.1, `AppEntry`).
class AppEntry {
  const AppEntry({
    required this.package,
    required this.label,
    required this.category,
    required this.system,
    required this.launchable,
    required this.essential,
    required this.state,
    required this.countsTowardLimit,
    required this.todayMs,
    required this.weekMs,
    required this.removed,
    this.versionName,
    this.installedAt,
    this.iconUrl,
    this.dailyLimitMinutes,
  });

  factory AppEntry.fromJson(JsonMap json) {
    final String package = json.str('package');
    final String? label = json.strOrNull('label');
    return AppEntry(
      package: package,
      label: label == null || label.trim().isEmpty ? package : label,
      category: AppCategory.parse(json.strOrNull('category')),
      system: json.boolOr('system', fallback: false),
      launchable: json.boolOr('launchable', fallback: true),
      essential: json.boolOr('essential', fallback: false),
      versionName: json.strOrNull('versionName'),
      installedAt: json.intOrNull('installedAt'),
      iconUrl: json.strOrNull('iconUrl'),
      state: AppRuleState.parse(json.strOrNull('state') ?? 'allowed'),
      countsTowardLimit: json.boolOr('countsTowardLimit', fallback: false),
      dailyLimitMinutes: json.intOrNull('dailyLimitMinutes'),
      todayMs: json.intOr('todayMs', fallback: 0),
      weekMs: json.intOr('weekMs', fallback: 0),
      removed: json.boolOr('removed', fallback: false),
    );
  }

  final String package;
  final String label;
  final AppCategory category;
  final bool system;

  /// Tem icone no launcher do aparelho.
  final bool launchable;

  /// Pacote que o aparelho nunca bloqueia (telefone, emergencia, tela inicial).
  final bool essential;
  final String? versionName;
  final int? installedAt;

  /// Caminho relativo e autenticado do icone, ou nulo.
  final String? iconUrl;

  /// Estado gravado na politica do servidor. As telas de edicao usam o rascunho local.
  final AppRuleState state;
  final bool countsTowardLimit;
  final int? dailyLimitMinutes;
  final int todayMs;
  final int weekMs;

  /// O app nao esta mais instalado no aparelho.
  final bool removed;

  /// Apps que fazem sentido na lista de regras: com icone no launcher ou instalados pelo
  /// usuario. Componentes internos do sistema ficam de fora.
  bool get isUserFacing => launchable || !system;
}

/// Inventario de um aparelho com o dia da cota a que os tempos de hoje se referem.
class DeviceApps {
  const DeviceApps({required this.day, required this.apps});

  factory DeviceApps.fromJson(JsonMap json) {
    return DeviceApps(
      day: json.strOrNull('day') ?? '',
      apps: json.objList('apps').map(AppEntry.fromJson).toList(),
    );
  }

  final String day;
  final List<AppEntry> apps;

  /// Apps com uso hoje, do mais usado para o menos usado.
  List<AppEntry> topToday({int limit = 5}) {
    final List<AppEntry> used = apps.where((AppEntry app) => app.todayMs > 0).toList()
      ..sort((AppEntry a, AppEntry b) => b.todayMs.compareTo(a.todayMs));
    return used.length > limit ? used.sublist(0, limit) : used;
  }
}
