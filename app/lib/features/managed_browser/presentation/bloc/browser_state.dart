part of 'browser_bloc.dart';

sealed class BrowserState extends Equatable {
  const BrowserState();
}

/// Lendo a configuracao do navegador.
final class BrowserLoading extends BrowserState {
  const BrowserLoading();

  @override
  List<Object?> get props => const <Object?>[];
}

/// O navegador foi desligado pelo responsavel ou o aparelho nao esta vinculado.
final class BrowserUnavailable extends BrowserState {
  const BrowserUnavailable();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Pronto para navegar.
final class BrowserReady extends BrowserState {
  const BrowserReady({
    required this.settings,
    this.url = '',
    this.title,
    this.progress = 0,
    this.loading = false,
    this.canGoBack = false,
    this.canGoForward = false,
    this.blocked,
    this.loadError,
    this.notice,
  });

  final BrowserSettings settings;

  /// Endereco da pagina atual. Vazio na pagina inicial.
  final String url;
  final String? title;

  /// Progresso do carregamento, de 0 a 100.
  final int progress;
  final bool loading;
  final bool canGoBack;
  final bool canGoForward;

  /// Pagina que o filtro acabou de barrar, mostrada no lugar do conteudo.
  final BlockedPage? blocked;

  /// Erro ao carregar a pagina principal.
  final String? loadError;

  /// Aviso passageiro (por exemplo, link de um tipo que nao abre aqui).
  final String? notice;

  /// Ha uma pagina aberta (ou barrada). Sem pagina, voltar fecha o navegador.
  bool get hasPage => url.isNotEmpty;

  bool get showStartPage => url.isEmpty && blocked == null;

  /// O cadeado so aparece para uma pagina segura que abriu de fato.
  bool get isSecure => blocked == null && loadError == null && url.startsWith('https://');

  BrowserReady copyWith({
    BrowserSettings? settings,
    String? url,
    int? progress,
    bool? loading,
    bool? canGoBack,
    bool? canGoForward,
  }) {
    return BrowserReady(
      settings: settings ?? this.settings,
      url: url ?? this.url,
      title: title,
      progress: progress ?? this.progress,
      loading: loading ?? this.loading,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
      blocked: blocked,
      loadError: loadError,
      notice: notice,
    );
  }

  /// Copia trocando a pagina: os campos que podem voltar a ser nulos ficam como informados.
  BrowserReady withPage({
    required String url,
    String? title,
    BlockedPage? blocked,
    String? loadError,
    String? notice,
    bool loading = false,
    int progress = 0,
  }) {
    return BrowserReady(
      settings: settings,
      url: url,
      title: title,
      progress: progress,
      loading: loading,
      canGoBack: canGoBack,
      canGoForward: canGoForward,
      blocked: blocked,
      loadError: loadError,
      notice: notice,
    );
  }

  /// Copia mantendo a pagina e trocando so o aviso passageiro.
  BrowserReady withNotice(String? notice) {
    return withPage(
      url: url,
      title: title,
      blocked: blocked,
      loadError: loadError,
      notice: notice,
      loading: loading,
      progress: progress,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    settings,
    url,
    title,
    progress,
    loading,
    canGoBack,
    canGoForward,
    blocked,
    loadError,
    notice,
  ];
}
