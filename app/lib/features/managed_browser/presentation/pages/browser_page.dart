import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../domain/entities/blocked_page.dart';
import '../../domain/entities/browser_settings.dart';
import '../bloc/browser_bloc.dart';
import '../engine/browser_engine.dart';
import '../texts/browser_texts.dart';

/// Tela do navegador gerenciado: barra de endereco, pagina e botoes de navegacao.
///
/// Precisa de um [BrowserBloc] e do [BrowserEngine] que ele comanda acima na arvore.
class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> with WidgetsBindingObserver {
  final TextEditingController _address = TextEditingController();
  final FocusNode _addressFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _addressFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _addressFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bloc.add(const BrowserSettingsRefreshRequested());
    }
  }

  BrowserBloc get _bloc => context.read<BrowserBloc>();

  String get _currentUrl {
    final BrowserState state = _bloc.state;
    return state is BrowserReady ? state.url : '';
  }

  void _onFocusChanged() {
    final String url = _currentUrl;
    if (_addressFocus.hasFocus) {
      // Em edicao mostra o endereco inteiro, ja selecionado para ser trocado.
      _address.value = TextEditingValue(
        text: url,
        selection: TextSelection(baseOffset: 0, extentOffset: url.length),
      );
    } else {
      _address.text = displayAddress(url);
    }
  }

  void _submit(String text) {
    _addressFocus.unfocus();
    _bloc.add(BrowserAddressSubmitted(text));
  }

  Future<void> _handleBack() async {
    final BrowserState state = _bloc.state;
    if (state is BrowserReady && state.hasPage) {
      _bloc.add(const BrowserBackRequested());
    } else {
      // Na pagina inicial nao ha para onde voltar: o navegador fecha.
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: <BlocListener<BrowserBloc, BrowserState>>[
        BlocListener<BrowserBloc, BrowserState>(
          listenWhen: (BrowserState previous, BrowserState current) {
            return _urlOf(previous) != _urlOf(current);
          },
          listener: (BuildContext context, BrowserState state) {
            if (!_addressFocus.hasFocus) {
              _address.text = displayAddress(_urlOf(state));
            }
          },
        ),
        BlocListener<BrowserBloc, BrowserState>(
          listenWhen: (BrowserState previous, BrowserState current) {
            final String? notice = _noticeOf(current);
            return notice != null && notice != _noticeOf(previous);
          },
          listener: (BuildContext context, BrowserState state) {
            showAppSnackBar(context, _noticeOf(state)!, tone: Tone.info);
            _bloc.add(const BrowserNoticeCleared());
          },
        ),
      ],
      child: BlocBuilder<BrowserBloc, BrowserState>(
        builder: (BuildContext context, BrowserState state) {
          return switch (state) {
            BrowserLoading() => const Scaffold(
              body: SafeArea(child: LoadingView(message: 'Abrindo o navegador...')),
            ),
            BrowserUnavailable() => const Scaffold(
              body: SafeArea(
                child: EmptyState(
                  icon: Icons.public_off_rounded,
                  title: 'Navegador indisponível',
                  message:
                      'O navegador seguro não está disponível agora. Ele pode ter sido desligado '
                      'pelo responsável, ou este aparelho ainda não foi vinculado.',
                ),
              ),
            ),
            final BrowserReady ready => _buildBrowser(context, ready),
          };
        },
      ),
    );
  }

  Widget _buildBrowser(BuildContext context, BrowserReady state) {
    final BrowserSettings settings = state.settings;
    final BlockedPage? blocked = state.blocked;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_handleBack());
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _AddressBar(
                controller: _address,
                focusNode: _addressFocus,
                secure: state.isSecure,
                onSubmitted: _submit,
              ),
              SizedBox(
                height: 3,
                child: state.loading
                    ? LinearProgressIndicator(
                        value: state.progress <= 0 ? null : state.progress / 100,
                      )
                    : null,
              ),
              if (settings.logHistory) const _HistoryNotice(),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    context.read<BrowserEngine>().buildView(context),
                    if (state.showStartPage) _StartPage(settings: settings),
                    if (state.loadError != null && blocked == null)
                      _Overlay(
                        child: EmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: 'A página não abriu',
                          message: state.loadError,
                          actionLabel: 'Tentar de novo',
                          onAction: () => _bloc.add(const BrowserReloadRequested()),
                        ),
                      ),
                    if (blocked != null)
                      BlockedPageView(
                        page: blocked,
                        onBack: () => _bloc.add(const BrowserBackRequested()),
                        onHome: () => _bloc.add(const BrowserHomeRequested()),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _NavigationBar(
          state: state,
          onBack: () => _bloc.add(const BrowserBackRequested()),
          onForward: () => _bloc.add(const BrowserForwardRequested()),
          onHome: () => _bloc.add(const BrowserHomeRequested()),
          onReload: () => _bloc.add(const BrowserReloadRequested()),
        ),
      ),
    );
  }

  static String _urlOf(BrowserState state) => state is BrowserReady ? state.url : '';

  static String? _noticeOf(BrowserState state) => state is BrowserReady ? state.notice : null;
}

class _AddressBar extends StatelessWidget {
  const _AddressBar({
    required this.controller,
    required this.focusNode,
    required this.secure,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool secure;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.go,
        autocorrect: false,
        enableSuggestions: false,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: 'Buscar ou digitar um endereço',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          prefixIcon: Icon(secure ? Icons.lock_outline : Icons.search_rounded, size: 20),
          suffixIcon: IconButton(
            tooltip: 'Limpar',
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () {
              controller.clear();
              focusNode.requestFocus();
            },
          ),
        ),
      ),
    );
  }
}

/// Aviso permanente de que o historico deste navegador e visto pelo responsavel.
class _HistoryNotice extends StatelessWidget {
  const _HistoryNotice();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(Icons.visibility_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'O responsável vê o histórico deste navegador.',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor, child: child);
  }
}

class _StartPage extends StatelessWidget {
  const _StartPage({required this.settings});

  final BrowserSettings settings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _Overlay(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.travel_explore_rounded,
                size: 38,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Navegador ParentaLynx', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Digite um endereço ou o que você quer procurar na barra de cima.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (settings.allowlistMode) ...<Widget>[
              const NoticeBanner(
                icon: Icons.checklist_rounded,
                message: 'Aqui só abrem os sites que o seu responsável escolheu.',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (settings.safeSearch) ...<Widget>[
              const NoticeBanner(
                tone: Tone.success,
                icon: Icons.verified_user_outlined,
                message: 'A busca segura está ligada: resultados impróprios ficam de fora.',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (settings.logHistory)
              const NoticeBanner(
                tone: Tone.neutral,
                icon: Icons.visibility_outlined,
                message:
                    'Os sites abertos aqui aparecem para o seu responsável: o endereço, o '
                    'título da página e o horário.',
              ),
          ],
        ),
      ),
    );
  }
}

/// Pagina mostrada no lugar de um site que o filtro barrou.
class BlockedPageView extends StatelessWidget {
  const BlockedPageView({
    required this.page,
    required this.onBack,
    required this.onHome,
    super.key,
  });

  final BlockedPage page;
  final VoidCallback onBack;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final StatusColors colors = StatusColors.of(context);
    return _Overlay(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: colors.warningContainer, shape: BoxShape.circle),
                child: Icon(Icons.front_hand_outlined, size: 40, color: colors.warning),
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Este site não abre aqui',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                page.domain,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                blockedReasonText(page.reason, page.category),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Se você acha que este site deveria abrir, converse com o seu responsável.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: onHome, child: const Text('Ir para a página inicial')),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.state,
    required this.onBack,
    required this.onForward,
    required this.onHome,
    required this.onReload,
  });

  final BrowserReady state;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onHome;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final bool hasPage = state.hasPage;
    return BottomAppBar(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          IconButton(
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: hasPage ? onBack : null,
          ),
          IconButton(
            tooltip: 'Avançar',
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: state.canGoForward ? onForward : null,
          ),
          IconButton(
            tooltip: 'Página inicial',
            icon: const Icon(Icons.home_outlined),
            onPressed: hasPage ? onHome : null,
          ),
          IconButton(
            tooltip: 'Recarregar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: hasPage ? onReload : null,
          ),
        ],
      ),
    );
  }
}
