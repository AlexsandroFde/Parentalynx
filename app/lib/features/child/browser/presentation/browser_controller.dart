import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../data/browser_repository.dart';
import '../domain/browser_navigation.dart';
import 'browser_engine.dart';

enum BrowserPhase {
  /// Lendo a configuracao do navegador.
  loading,

  /// O navegador foi desligado pelo responsavel ou o aparelho nao esta vinculado.
  disabled,

  /// Pronto para navegar.
  ready,
}

class BrowserState {
  const BrowserState({
    this.phase = BrowserPhase.loading,
    this.settings,
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

  final BrowserPhase phase;
  final BrowserSettings? settings;

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

  bool get showStartPage => url.isEmpty && blocked == null;

  BrowserState copyWith({
    BrowserPhase? phase,
    BrowserSettings? settings,
    String? url,
    int? progress,
    bool? loading,
    bool? canGoBack,
    bool? canGoForward,
  }) {
    return BrowserState(
      phase: phase ?? this.phase,
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

  /// Copia trocando os campos que podem voltar a ser nulos.
  BrowserState withPage({
    required String url,
    String? title,
    BlockedPage? blocked,
    String? loadError,
    String? notice,
    bool loading = false,
    int progress = 0,
  }) {
    return BrowserState(
      phase: phase,
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
}

final browserControllerProvider = NotifierProvider.autoDispose<BrowserController, BrowserState>(
  BrowserController.new,
);

/// Controla o navegador gerenciado: toda navegacao de pagina principal passa pelo filtro do
/// agente nativo antes de carregar, e o que foi aberto ou barrado vai para o historico que o
/// responsavel ve.
class BrowserController extends Notifier<BrowserState> implements BrowserEngineDelegate {
  static const int _approvedLimit = 200;

  /// Enderecos que o filtro ja liberou nesta sessao.
  final LinkedHashSet<String> _approved = LinkedHashSet<String>();
  late BrowserEngine _engine;
  late BrowserRepository _repository;
  String? _lastRecorded;

  @override
  BrowserState build() {
    _engine = ref.watch(browserEngineProvider);
    _repository = ref.watch(browserRepositoryProvider);
    _engine.attach(this);
    Future<void>.microtask(refreshSettings);
    return const BrowserState();
  }

  /// Le a configuracao do navegador. Chamado ao abrir e quando o app volta ao primeiro plano,
  /// porque as regras podem ter mudado.
  Future<void> refreshSettings() async {
    try {
      final BrowserSettings settings = await _repository.settings();
      if (!ref.mounted) {
        return;
      }
      // As liberacoes antigas deixam de valer: a politica pode ter mudado.
      _approved.clear();
      state = state.copyWith(
        phase: settings.enabled ? BrowserPhase.ready : BrowserPhase.disabled,
        settings: settings,
      );
    } on AppFailure {
      if (ref.mounted && state.phase == BrowserPhase.loading) {
        state = state.copyWith(phase: BrowserPhase.disabled);
      }
    }
  }

  /// Abre o que foi digitado na barra: um endereco ou uma busca.
  Future<void> submitAddress(String input) async {
    final Uri? uri = resolveAddressInput(input);
    if (uri != null) {
      await open(uri.toString());
    }
  }

  /// Abre um endereco, depois de passar pelo filtro.
  Future<void> open(String url) async {
    if (state.phase != BrowserPhase.ready) {
      return;
    }
    if (!isWebUrl(url)) {
      state = state.withPage(
        url: state.url,
        title: state.title,
        blocked: state.blocked,
        loading: state.loading,
        progress: state.progress,
        notice: 'Este tipo de endereço não abre no navegador seguro.',
      );
      return;
    }
    state = state.withPage(url: url, loading: true, progress: 5);
    final NavigationVerdict verdict = await _evaluate(url);
    if (!ref.mounted) {
      return;
    }
    if (!verdict.allowed) {
      await _block(url, verdict);
      return;
    }
    final String target = _targetOf(url, verdict);
    _approve(target);
    state = state.withPage(url: target, loading: true, progress: 10);
    await _engine.load(target);
  }

  Future<void> reload() async {
    final BlockedPage? blocked = state.blocked;
    if (blocked != null) {
      await open(blocked.url);
    } else if (state.url.isNotEmpty) {
      await _engine.reload();
    }
  }

  /// Volta uma pagina. Devolve falso quando nao ha para onde voltar.
  Future<bool> goBack() async {
    if (state.blocked != null || state.loadError != null) {
      if (await _engine.canGoBack()) {
        state = state.withPage(url: state.url, loading: true);
        await _engine.goBack();
      } else {
        await goHome();
      }
      return true;
    }
    if (state.url.isNotEmpty && await _engine.canGoBack()) {
      await _engine.goBack();
      return true;
    }
    if (state.url.isNotEmpty) {
      await goHome();
      return true;
    }
    return false;
  }

  Future<void> goForward() async {
    if (await _engine.canGoForward()) {
      await _engine.goForward();
    }
  }

  /// Volta a pagina inicial do navegador.
  Future<void> goHome() async {
    state = state.withPage(url: '');
    await _engine.load(blankPageUrl);
    await _updateNavigationFlags();
  }

  void clearNotice() {
    if (state.notice != null) {
      state = state.withPage(
        url: state.url,
        title: state.title,
        blocked: state.blocked,
        loadError: state.loadError,
        loading: state.loading,
        progress: state.progress,
      );
    }
  }

  @override
  Future<bool> onNavigationRequest(String url, {required bool isMainFrame}) async {
    if (!isMainFrame || url == blankPageUrl) {
      return true;
    }
    if (!isWebUrl(url)) {
      state = state.withPage(
        url: state.url,
        title: state.title,
        blocked: state.blocked,
        loading: state.loading,
        progress: state.progress,
        notice: 'Este tipo de link não abre no navegador seguro.',
      );
      return false;
    }
    if (_approved.contains(url)) {
      return true;
    }
    final NavigationVerdict verdict = await _evaluate(url);
    if (!ref.mounted) {
      return false;
    }
    if (!verdict.allowed) {
      await _block(url, verdict);
      return false;
    }
    final String target = _targetOf(url, verdict);
    _approve(target);
    if (target != url) {
      // Busca segura: carrega o endereco reescrito no lugar do pedido.
      unawaited(_engine.load(target));
      return false;
    }
    return true;
  }

  @override
  void onPageStarted(String url) {
    if (url == blankPageUrl) {
      return;
    }
    state = state.withPage(url: url, loading: true, progress: 10);
    if (isWebUrl(url) && !_approved.contains(url)) {
      // Rede de seguranca para navegacoes que nao passam pelo pedido de navegacao (voltar,
      // avancar, redirecionamento por script): confere e cobre a pagina se for barrada.
      unawaited(_checkStartedPage(url));
    }
  }

  @override
  void onProgress(int progress) {
    if (state.loading && state.blocked == null) {
      state = state.copyWith(progress: progress.clamp(0, 100));
    }
  }

  @override
  void onUrlChanged(String url) {
    if (url != blankPageUrl && state.blocked == null && state.url.isNotEmpty) {
      state = state.copyWith(url: url);
    }
  }

  @override
  void onPageFinished(String url) {
    unawaited(_finishPage(url));
  }

  @override
  void onMainFrameError(String description) {
    if (state.blocked != null || state.url.isEmpty) {
      return;
    }
    state = state.withPage(
      url: state.url,
      loadError: 'Não foi possível abrir esta página. Confira a internet e tente de novo.',
    );
  }

  Future<void> _finishPage(String url) async {
    await _updateNavigationFlags();
    if (!ref.mounted || url == blankPageUrl || state.blocked != null) {
      return;
    }
    String? title;
    try {
      title = await _engine.title();
    } on Object {
      title = null;
    }
    if (!ref.mounted || state.blocked != null) {
      return;
    }
    state = state.withPage(url: url, title: title, loadError: state.loadError, progress: 100);
    if (state.loadError == null && isWebUrl(url) && url != _lastRecorded) {
      _lastRecorded = url;
      await _record(url, title: title);
    }
  }

  Future<void> _checkStartedPage(String url) async {
    final NavigationVerdict verdict = await _evaluate(url);
    if (!ref.mounted || state.url != url) {
      return;
    }
    if (verdict.allowed) {
      _approve(url);
      return;
    }
    await _block(url, verdict);
    await _engine.load(blankPageUrl);
  }

  Future<NavigationVerdict> _evaluate(String url) async {
    try {
      return await _repository.evaluate(url);
    } on AppFailure {
      // Sem resposta do filtro a pagina nao abre.
      return const NavigationVerdict.checkFailed();
    }
  }

  Future<void> _block(String url, NavigationVerdict verdict) async {
    state = state.withPage(
      url: url,
      blocked: BlockedPage(url: url, reason: verdict.reason, category: verdict.category),
    );
    if (verdict.reason != NavigationVerdict.checkFailedReason) {
      await _record(url, blocked: true, reason: verdict.reason);
    }
  }

  Future<void> _record(String url, {String? title, bool blocked = false, String? reason}) async {
    if (!(state.settings?.logHistory ?? false)) {
      return;
    }
    try {
      await _repository.recordVisit(url, title: title, blocked: blocked, reason: reason);
    } on AppFailure {
      // O historico e melhor esforco: uma falha ao registrar nao interrompe a navegacao.
    }
  }

  Future<void> _updateNavigationFlags() async {
    try {
      final bool back = await _engine.canGoBack();
      final bool forward = await _engine.canGoForward();
      if (ref.mounted) {
        state = state.copyWith(canGoBack: back, canGoForward: forward);
      }
    } on Object {
      // O motor ainda nao esta pronto. Os botoes ficam como estavam.
    }
  }

  String _targetOf(String url, NavigationVerdict verdict) {
    final String? rewritten = verdict.rewrittenUrl;
    return rewritten != null && rewritten.isNotEmpty && isWebUrl(rewritten) ? rewritten : url;
  }

  void _approve(String url) {
    _approved
      ..remove(url)
      ..add(url);
    while (_approved.length > _approvedLimit) {
      _approved.remove(_approved.first);
    }
  }
}
