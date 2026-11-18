import 'package:equatable/equatable.dart';

enum WebMode { blocklist, allowlist }

/// Categorias de sites que o navegador gerenciado sabe bloquear.
///
/// O [code] e o identificador gravado na politica (`blockedCategories`). A politica guarda os
/// codigos como texto, para nao perder categorias criadas por versoes mais novas.
enum WebCategory {
  adult('adult', 'Conteúdo adulto'),
  gambling('gambling', 'Apostas e jogos de azar'),
  social('social', 'Redes sociais'),
  video('video', 'Vídeo e streaming'),
  games('games', 'Jogos');

  const WebCategory(this.code, this.label);

  final String code;
  final String label;

  static WebCategory? fromCode(String code) {
    for (final WebCategory category in values) {
      if (category.code == code) {
        return category;
      }
    }
    return null;
  }
}

/// Regras de navegacao (protocolo, secao 4.2, `web`).
final class WebPolicy extends Equatable {
  const WebPolicy({
    this.managedBrowser = true,
    this.logHistory = true,
    this.safeDns = true,
    this.safeSearch = true,
    this.mode = WebMode.blocklist,
    this.blockedDomains = const <String>[],
    this.allowedDomains = const <String>[],
    this.blockedCategories = const <String>['adult', 'gambling'],
  });

  final bool managedBrowser;
  final bool logHistory;
  final bool safeDns;
  final bool safeSearch;
  final WebMode mode;
  final List<String> blockedDomains;
  final List<String> allowedDomains;
  final List<String> blockedCategories;

  WebPolicy copyWith({
    bool? managedBrowser,
    bool? logHistory,
    bool? safeDns,
    bool? safeSearch,
    WebMode? mode,
    List<String>? blockedDomains,
    List<String>? allowedDomains,
    List<String>? blockedCategories,
  }) {
    return WebPolicy(
      managedBrowser: managedBrowser ?? this.managedBrowser,
      logHistory: logHistory ?? this.logHistory,
      safeDns: safeDns ?? this.safeDns,
      safeSearch: safeSearch ?? this.safeSearch,
      mode: mode ?? this.mode,
      blockedDomains: blockedDomains ?? this.blockedDomains,
      allowedDomains: allowedDomains ?? this.allowedDomains,
      blockedCategories: blockedCategories ?? this.blockedCategories,
    );
  }

  /// Limpa um dominio digitado: sem esquema, caminho, `www.` e em minusculas. Devolve nulo se
  /// o resultado nao parece um dominio.
  static String? normalizeDomain(String input) {
    String value = input.trim().toLowerCase();
    value = value.replaceFirst(RegExp(r'^[a-z][a-z0-9+.-]*://'), '');
    value = value.split('/').first.split('?').first.split('#').first;
    value = value.split('@').last.split(':').first;
    if (value.startsWith('www.')) {
      value = value.substring(4);
    }
    final RegExp pattern = RegExp(r'^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$');
    return pattern.hasMatch(value) ? value : null;
  }

  @override
  List<Object?> get props => <Object?>[
    managedBrowser,
    logHistory,
    safeDns,
    safeSearch,
    mode,
    blockedDomains,
    allowedDomains,
    blockedCategories,
  ];
}
