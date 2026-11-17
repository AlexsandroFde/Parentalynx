import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/platform/native_providers.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../domain/browser_navigation.dart';
import 'browser_controller.dart';
import 'browser_engine.dart';

/// Tela do navegador gerenciado: barra de endereco, pagina e botoes de navegacao.
class BrowserPage extends ConsumerStatefulWidget {
  const BrowserPage({super.key});

  @override
  ConsumerState<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends ConsumerState<BrowserPage> with WidgetsBindingObserver {
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
      unawaited(ref.read(browserControllerProvider.notifier).refreshSettings());
    }
  }

  BrowserController get _controller => ref.read(browserControllerProvider.notifier);

  void _onFocusChanged() {
    final String url = ref.read(browserControllerProvider).url;
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
    unawaited(_controller.submitAddress(text));
  }

  Future<void> _handleBack() async {
    final bool handled = await _controller.goBack();
    if (!handled) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BrowserState>(browserControllerProvider, (
      BrowserState? previous,
      BrowserState next,
    ) {
      if (!_addressFocus.hasFocus && previous?.url != next.url) {
        _address.text = displayAddress(next.url);
      }
      final String? notice = next.notice;
      if (notice != null && notice != previous?.notice) {
        showAppSnackBar(context, notice, tone: Tone.info);
        _controller.clearNotice();
      }
    });
    // Endereco pedido por outro app (link tocado) ou pela tela da crianca.
    ref.listen<String?>(browserOpenUrlProvider, (String? previous, String? next) {
      _openRequested();
    });
    ref.listen<BrowserPhase>(
      browserControllerProvider.select((BrowserState value) => value.phase),
      (BrowserPhase? previous, BrowserPhase next) => _openRequested(),
    );

    final BrowserState state = ref.watch(browserControllerProvider);
    if (state.phase == BrowserPhase.loading) {
      return const Scaffold(
        body: SafeArea(child: LoadingView(message: 'Abrindo o navegador...')),
      );
    }
    if (state.phase == BrowserPhase.disabled) {
      return const Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.public_off_rounded,
            title: 'Navegador indisponível',
            message:
                'O navegador seguro não está disponível agora. Ele pode ter sido desligado '
                'pelo responsável, ou este aparelho ainda não foi vinculado.',
          ),
        ),
      );
    }
    final BrowserSettings? settings = state.settings;
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
                // O cadeado so aparece para uma pagina que abriu de fato.
                secure:
                    state.blocked == null &&
                    state.loadError == null &&
                    state.url.startsWith('https://'),
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
              if (settings != null && settings.logHistory) const _HistoryNotice(),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ref.watch(browserEngineProvider).buildView(context),
                    if (state.showStartPage) _StartPage(settings: settings),
                    if (state.loadError != null && state.blocked == null)
                      _Overlay(
                        child: EmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: 'A página não abriu',
                          message: state.loadError,
                          actionLabel: 'Tentar de novo',
                          onAction: () => unawaited(_controller.reload()),
                        ),
                      ),
                    if (state.blocked != null)
                      BlockedPageView(
                        page: state.blocked!,
                        onBack: () => unawaited(_controller.goBack()),
                        onHome: () => unawaited(_controller.goHome()),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _NavigationBar(
          state: state,
          onBack: () => unawaited(_controller.goBack()),
          onForward: () => unawaited(_controller.goForward()),
          onHome: () => unawaited(_controller.goHome()),
          onReload: () => unawaited(_controller.reload()),
        ),
      ),
    );
  }

  void _openRequested() {
    final String? url = ref.read(browserOpenUrlProvider);
    if (url == null || ref.read(browserControllerProvider).phase != BrowserPhase.ready) {
      return;
    }
    ref.read(browserOpenUrlProvider.notifier).consume();
    unawaited(_controller.open(url));
  }
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

  final BrowserSettings? settings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BrowserSettings? current = settings;
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
            if (current != null && current.allowlistMode) ...<Widget>[
              const NoticeBanner(
                icon: Icons.checklist_rounded,
                message: 'Aqui só abrem os sites que o seu responsável escolheu.',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (current != null && current.safeSearch) ...<Widget>[
              const NoticeBanner(
                tone: Tone.success,
                icon: Icons.verified_user_outlined,
                message: 'A busca segura está ligada: resultados impróprios ficam de fora.',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (current != null && current.logHistory)
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

  final BrowserState state;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onHome;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final bool hasPage = state.url.isNotEmpty;
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
