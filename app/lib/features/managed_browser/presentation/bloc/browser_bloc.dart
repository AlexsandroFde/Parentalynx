import 'dart:async';
import 'dart:collection';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/event_transformers.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/blocked_page.dart';
import '../../domain/entities/browser_settings.dart';
import '../../domain/entities/browser_visit.dart';
import '../../domain/entities/navigation_verdict.dart';
import '../../domain/services/browser_navigation_rules.dart';
import '../../domain/usecases/evaluate_navigation.dart';
import '../../domain/usecases/get_browser_settings.dart';
import '../../domain/usecases/record_browser_visit.dart';
import '../../domain/usecases/watch_browser_url_requests.dart';
import '../engine/browser_engine.dart';
import '../texts/browser_texts.dart';

part 'browser_event.dart';
part 'browser_state.dart';

/// Navegador gerenciado: toda navegacao de pagina principal passa pelo filtro do agente
/// nativo antes de carregar, e o que foi aberto ou barrado vai para o historico que o
/// responsavel ve.
///
/// Comanda o [BrowserEngine] e recebe os eventos dele como eventos do BLoC.
class BrowserBloc extends Bloc<BrowserEvent, BrowserState> {
  BrowserBloc({
    required this._engine,
    required this._getBrowserSettings,
    required this._evaluateNavigation,
    required this._recordBrowserVisit,
    required this._watchBrowserUrlRequests,
  }) : super(const BrowserLoading()) {
    on<BrowserStarted>(_onStarted, transformer: restartable());
    on<BrowserSettingsRefreshRequested>(_onSettingsRefreshRequested, transformer: restartable());
    on<BrowserAddressSubmitted>(_onAddressSubmitted, transformer: droppable());
    on<BrowserUrlRequested>(_onUrlRequested, transformer: sequential());
    on<BrowserReloadRequested>(_onReloadRequested, transformer: droppable());
    on<BrowserBackRequested>(_onBackRequested, transformer: droppable());
    on<BrowserForwardRequested>(_onForwardRequested, transformer: droppable());
    on<BrowserHomeRequested>(_onHomeRequested, transformer: droppable());
    on<BrowserNoticeCleared>(_onNoticeCleared);
    // Eventos do motor: cada pedido de navegacao precisa de resposta, entao nenhum e
    // descartado.
    on<BrowserNavigationRequested>(_onNavigationRequested, transformer: concurrent());
    on<BrowserPageStarted>(_onPageStarted, transformer: concurrent());
    on<BrowserPageFinished>(_onPageFinished, transformer: concurrent());
    on<BrowserProgressChanged>(_onProgressChanged);
    on<BrowserUrlChanged>(_onUrlChanged);
    on<BrowserMainFrameFailed>(_onMainFrameFailed);
    _engine.attach(_EngineEvents(this));
  }

  static const int _approvedLimit = 200;

  final BrowserEngine _engine;
  final GetBrowserSettings _getBrowserSettings;
  final EvaluateNavigation _evaluateNavigation;
  final RecordBrowserVisit _recordBrowserVisit;
  final WatchBrowserUrlRequests _watchBrowserUrlRequests;

  /// Enderecos que o filtro ja liberou nesta sessao.
  final LinkedHashSet<String> _approved = LinkedHashSet<String>();

  /// Pedidos de navegacao do motor ainda sem resposta.
  final Set<Completer<bool>> _pendingDecisions = <Completer<bool>>{};

  /// Endereco pedido por outro app enquanto o navegador ainda nao estava pronto.
  String? _pendingUrl;
  String? _lastRecorded;

  Future<void> _onStarted(BrowserStarted event, Emitter<BrowserState> emit) async {
    add(const BrowserSettingsRefreshRequested());
    await emit.onEach<String>(
      _watchBrowserUrlRequests(),
      onData: (String url) => add(BrowserUrlRequested(url)),
    );
  }

  Future<void> _onSettingsRefreshRequested(
    BrowserSettingsRefreshRequested event,
    Emitter<BrowserState> emit,
  ) async {
    final Result<BrowserSettings> result = await _getBrowserSettings();
    switch (result) {
      case Ok<BrowserSettings>(value: final BrowserSettings settings):
        // As liberacoes antigas deixam de valer: a politica pode ter mudado.
        _approved.clear();
        final BrowserState current = state;
        if (!settings.enabled) {
          emit(const BrowserUnavailable());
        } else if (current is BrowserReady) {
          emit(current.copyWith(settings: settings));
        } else {
          emit(BrowserReady(settings: settings));
          final String? pending = _pendingUrl;
          if (pending != null) {
            _pendingUrl = null;
            add(BrowserUrlRequested(pending));
          }
        }
      case Err<BrowserSettings>():
        if (state is BrowserLoading) {
          emit(const BrowserUnavailable());
        }
    }
  }

  Future<void> _onAddressSubmitted(
    BrowserAddressSubmitted event,
    Emitter<BrowserState> emit,
  ) async {
    final Uri? uri = resolveAddressInput(event.input);
    if (uri != null) {
      await _open(uri.toString(), emit);
    }
  }

  Future<void> _onUrlRequested(BrowserUrlRequested event, Emitter<BrowserState> emit) async {
    if (state is! BrowserReady) {
      // Abre quando o navegador ficar pronto.
      _pendingUrl = event.url;
      return;
    }
    await _open(event.url, emit);
  }

  Future<void> _onReloadRequested(BrowserReloadRequested event, Emitter<BrowserState> emit) async {
    final BrowserState current = state;
    if (current is! BrowserReady) {
      return;
    }
    final BlockedPage? blocked = current.blocked;
    if (blocked != null) {
      await _open(blocked.url, emit);
    } else if (current.hasPage) {
      await _engine.reload();
    }
  }

  Future<void> _onBackRequested(BrowserBackRequested event, Emitter<BrowserState> emit) async {
    final BrowserState current = state;
    if (current is! BrowserReady) {
      return;
    }
    if (current.blocked != null || current.loadError != null) {
      if (await _engine.canGoBack()) {
        _emitReady(emit, (BrowserReady now) => now.withPage(url: now.url, loading: true));
        await _engine.goBack();
      } else {
        await _goHome(emit);
      }
      return;
    }
    if (current.hasPage && await _engine.canGoBack()) {
      await _engine.goBack();
      return;
    }
    if (current.hasPage) {
      await _goHome(emit);
    }
  }

  Future<void> _onForwardRequested(
    BrowserForwardRequested event,
    Emitter<BrowserState> emit,
  ) async {
    if (await _engine.canGoForward()) {
      await _engine.goForward();
    }
  }

  Future<void> _onHomeRequested(BrowserHomeRequested event, Emitter<BrowserState> emit) {
    return _goHome(emit);
  }

  void _onNoticeCleared(BrowserNoticeCleared event, Emitter<BrowserState> emit) {
    final BrowserState current = state;
    if (current is BrowserReady && current.notice != null) {
      emit(current.withNotice(null));
    }
  }

  Future<void> _onNavigationRequested(
    BrowserNavigationRequested event,
    Emitter<BrowserState> emit,
  ) async {
    bool allow = false;
    try {
      allow = await _decideNavigation(event.url, isMainFrame: event.isMainFrame, emit: emit);
    } finally {
      _answer(event.decision, allow);
    }
  }

  Future<bool> _decideNavigation(
    String url, {
    required bool isMainFrame,
    required Emitter<BrowserState> emit,
  }) async {
    if (!isMainFrame || url == blankPageUrl) {
      return true;
    }
    if (state is! BrowserReady) {
      return false;
    }
    if (!isWebUrl(url)) {
      _emitReady(emit, (BrowserReady now) => now.withNotice(unsupportedLinkNotice));
      return false;
    }
    if (_approved.contains(url)) {
      return true;
    }
    final NavigationVerdict verdict = await _evaluateNavigation(url);
    if (isClosed) {
      return false;
    }
    if (!verdict.allowed) {
      await _block(url, verdict, emit);
      return false;
    }
    final String target = verdict.targetFor(url);
    _approve(target);
    if (target != url) {
      // Busca segura: carrega o endereco reescrito no lugar do pedido.
      unawaited(_engine.load(target));
      return false;
    }
    return true;
  }

  Future<void> _onPageStarted(BrowserPageStarted event, Emitter<BrowserState> emit) async {
    final String url = event.url;
    if (url == blankPageUrl || state is! BrowserReady) {
      return;
    }
    _emitReady(emit, (BrowserReady now) => now.withPage(url: url, loading: true, progress: 10));
    if (isWebUrl(url) && !_approved.contains(url)) {
      // Rede de seguranca para navegacoes que nao passam pelo pedido de navegacao (voltar,
      // avancar, redirecionamento por script): confere e cobre a pagina se for barrada.
      await _checkStartedPage(url, emit);
    }
  }

  void _onProgressChanged(BrowserProgressChanged event, Emitter<BrowserState> emit) {
    final BrowserState current = state;
    if (current is BrowserReady && current.loading && current.blocked == null) {
      emit(current.copyWith(progress: event.progress.clamp(0, 100)));
    }
  }

  void _onUrlChanged(BrowserUrlChanged event, Emitter<BrowserState> emit) {
    final BrowserState current = state;
    if (event.url != blankPageUrl &&
        current is BrowserReady &&
        current.blocked == null &&
        current.hasPage) {
      emit(current.copyWith(url: event.url));
    }
  }

  void _onMainFrameFailed(BrowserMainFrameFailed event, Emitter<BrowserState> emit) {
    final BrowserState current = state;
    if (current is! BrowserReady || current.blocked != null || !current.hasPage) {
      return;
    }
    emit(current.withPage(url: current.url, loadError: pageLoadErrorMessage));
  }

  Future<void> _onPageFinished(BrowserPageFinished event, Emitter<BrowserState> emit) async {
    final String url = event.url;
    await _updateNavigationFlags(emit);
    if (url == blankPageUrl || !_isShowingContent) {
      return;
    }
    String? title;
    try {
      title = await _engine.title();
    } on Object {
      title = null;
    }
    final BrowserState current = state;
    if (current is! BrowserReady || current.blocked != null) {
      return;
    }
    final BrowserReady finished = current.withPage(
      url: url,
      title: title,
      loadError: current.loadError,
      progress: 100,
    );
    emit(finished);
    if (finished.loadError == null && isWebUrl(url) && url != _lastRecorded) {
      _lastRecorded = url;
      await _recordBrowserVisit(
        BrowserVisit.opened(url: url, title: title),
        settings: finished.settings,
      );
    }
  }

  /// Abre um endereco, depois de passar pelo filtro.
  Future<void> _open(String url, Emitter<BrowserState> emit) async {
    if (state is! BrowserReady) {
      return;
    }
    if (!isWebUrl(url)) {
      _emitReady(emit, (BrowserReady now) => now.withNotice(unsupportedAddressNotice));
      return;
    }
    _emitReady(emit, (BrowserReady now) => now.withPage(url: url, loading: true, progress: 5));
    final NavigationVerdict verdict = await _evaluateNavigation(url);
    if (isClosed || state is! BrowserReady) {
      return;
    }
    if (!verdict.allowed) {
      await _block(url, verdict, emit);
      return;
    }
    final String target = verdict.targetFor(url);
    _approve(target);
    _emitReady(emit, (BrowserReady now) => now.withPage(url: target, loading: true, progress: 10));
    await _engine.load(target);
  }

  Future<void> _goHome(Emitter<BrowserState> emit) async {
    _emitReady(emit, (BrowserReady now) => now.withPage(url: ''));
    await _engine.load(blankPageUrl);
    await _updateNavigationFlags(emit);
  }

  Future<void> _checkStartedPage(String url, Emitter<BrowserState> emit) async {
    final NavigationVerdict verdict = await _evaluateNavigation(url);
    final BrowserState current = state;
    if (isClosed || current is! BrowserReady || current.url != url) {
      return;
    }
    if (verdict.allowed) {
      _approve(url);
      return;
    }
    await _block(url, verdict, emit);
    await _engine.load(blankPageUrl);
  }

  Future<void> _block(String url, NavigationVerdict verdict, Emitter<BrowserState> emit) async {
    final BrowserState current = state;
    if (current is! BrowserReady) {
      return;
    }
    emit(
      current.withPage(
        url: url,
        blocked: BlockedPage(url: url, reason: verdict.reason, category: verdict.category),
      ),
    );
    await _recordBrowserVisit(
      BrowserVisit.blocked(url: url, reason: verdict.reason),
      settings: current.settings,
    );
  }

  Future<void> _updateNavigationFlags(Emitter<BrowserState> emit) async {
    try {
      final bool back = await _engine.canGoBack();
      final bool forward = await _engine.canGoForward();
      _emitReady(emit, (BrowserReady now) => now.copyWith(canGoBack: back, canGoForward: forward));
    } on Object {
      // O motor ainda nao esta pronto. Os botoes ficam como estavam.
    }
  }

  bool get _isShowingContent {
    final BrowserState current = state;
    return current is BrowserReady && current.blocked == null;
  }

  /// Emite a partir do estado atual, se o navegador estiver pronto.
  void _emitReady(Emitter<BrowserState> emit, BrowserReady Function(BrowserReady now) change) {
    final BrowserState current = state;
    if (current is BrowserReady && !emit.isDone) {
      emit(change(current));
    }
  }

  void _approve(String url) {
    _approved
      ..remove(url)
      ..add(url);
    while (_approved.length > _approvedLimit) {
      _approved.remove(_approved.first);
    }
  }

  Future<bool> _requestNavigation(String url, {required bool isMainFrame}) {
    if (isClosed) {
      return Future<bool>.value(false);
    }
    final Completer<bool> decision = Completer<bool>();
    _pendingDecisions.add(decision);
    add(BrowserNavigationRequested(url: url, isMainFrame: isMainFrame, decision: decision));
    return decision.future;
  }

  void _answer(Completer<bool> decision, bool allow) {
    _pendingDecisions.remove(decision);
    if (!decision.isCompleted) {
      decision.complete(allow);
    }
  }

  void _addFromEngine(BrowserEvent event) {
    if (!isClosed) {
      add(event);
    }
  }

  @override
  Future<void> close() {
    // O motor nao pode ficar esperando: pedidos sem resposta sao recusados.
    for (final Completer<bool> decision in _pendingDecisions.toList()) {
      _answer(decision, false);
    }
    return super.close();
  }
}

/// Liga os avisos do motor aos eventos do BLoC.
class _EngineEvents implements BrowserEngineDelegate {
  const _EngineEvents(this._bloc);

  final BrowserBloc _bloc;

  @override
  Future<bool> onNavigationRequest(String url, {required bool isMainFrame}) {
    return _bloc._requestNavigation(url, isMainFrame: isMainFrame);
  }

  @override
  void onPageStarted(String url) => _bloc._addFromEngine(BrowserPageStarted(url));

  @override
  void onPageFinished(String url) => _bloc._addFromEngine(BrowserPageFinished(url));

  @override
  void onProgress(int progress) => _bloc._addFromEngine(BrowserProgressChanged(progress));

  @override
  void onUrlChanged(String url) => _bloc._addFromEngine(BrowserUrlChanged(url));

  @override
  void onMainFrameError(String description) {
    _bloc._addFromEngine(BrowserMainFrameFailed(description));
  }
}
