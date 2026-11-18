import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/blocked_page.dart';
import '../../domain/entities/browser_settings.dart';
import '../../domain/entities/navigation_verdict.dart';
import '../bloc/browser_bloc.dart';
import '../engine/browser_engine.dart';
import '../texts/browser_texts.dart';

/// Tela do navegador gerenciado: barra de endereco, pagina e botoes de navegacao.
///
/// Usada pela crianca: fica no perfil da crianca do Design System (o `BrowserApp` monta o
/// tema). Precisa de um [BrowserBloc] e do [BrowserEngine] que ele comanda acima na arvore.
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
              body: SafeArea(child: LoadingState(message: 'Abrindo o navegador...')),
            ),
            BrowserUnavailable() => const Scaffold(
              body: SafeArea(
                child: EmptyState(
                  icon: AppIcons.webBlocked,
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
                height: _progressHeight,
                child: state.loading
                    ? LinearProgressIndicator(
                        minHeight: _progressHeight,
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
                          icon: AppIcons.offline,
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
                        onRetry: () => _bloc.add(const BrowserReloadRequested()),
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

  /// Altura da linha de progresso do carregamento, logo abaixo da barra de endereco.
  static const double _progressHeight = AppSizes.focusRing + AppSizes.hairline;

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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          prefixIcon: Icon(secure ? AppIcons.lock : AppIcons.search, size: AppSizes.iconMd),
          suffixIcon: AppIconButton(
            icon: AppIcons.close,
            tooltip: 'Limpar',
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
    final Color color = context.colors.textSecondary;
    return Container(
      width: double.infinity,
      color: context.colors.surfaceMuted,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Icon(AppIcons.show, size: AppSizes.iconSm, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'O responsável vê o histórico deste navegador.',
              style: context.text.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fundo que cobre a pagina do motor (inicio, bloqueio, erro).
class _Overlay extends StatelessWidget {
  const _Overlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: context.colors.canvas, child: child);
  }
}

/// Icone em destaque dentro de um circulo, no topo das paginas do navegador.
class _Medallion extends StatelessWidget {
  const _Medallion({required this.icon, required this.tone});

  final IconData icon;
  final Tone tone;

  static const double _size = AppSizes.avatarLg + AppSpacing.xl;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(color: tone.background(context), shape: BoxShape.circle),
        child: Icon(icon, size: AppSizes.iconXl, color: tone.foreground(context)),
      ),
    );
  }
}

class _StartPage extends StatelessWidget {
  const _StartPage({required this.settings});

  final BrowserSettings settings;

  @override
  Widget build(BuildContext context) {
    return _Overlay(
      child: ChildPageBody(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.xxl,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          const Center(
            child: _Medallion(icon: AppIcons.web, tone: Tone.info),
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              'Navegador ParentaLynx',
              textAlign: TextAlign.center,
              style: context.text.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Digite um endereço ou o que você quer procurar na barra de cima.',
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary),
          ),
          if (settings.allowlistMode || settings.safeSearch || settings.logHistory) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            AppPanel(
              child: Column(
                children: <Widget>[
                  if (settings.allowlistMode)
                    const BulletLine(
                      icon: AppIcons.checklist,
                      text: 'Aqui só abrem os sites que o seu responsável escolheu.',
                    ),
                  if (settings.safeSearch)
                    const BulletLine(
                      icon: AppIcons.verifiedUser,
                      tone: Tone.success,
                      text: 'A busca segura está ligada: resultados impróprios ficam de fora.',
                    ),
                  if (settings.logHistory)
                    const BulletLine(
                      icon: AppIcons.show,
                      tone: Tone.neutral,
                      text:
                          'Os sites abertos aqui aparecem para o seu responsável: o endereço, o '
                          'título da página e o horário.',
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pagina mostrada no lugar de um site que o filtro barrou.
///
/// Diz o motivo sem tom de castigo (tom neutro, nunca o vermelho) e oferece o caminho de
/// volta. Quando o filtro nao respondeu, nao e uma regra: a acao principal e tentar de novo.
class BlockedPageView extends StatelessWidget {
  const BlockedPageView({
    required this.page,
    required this.onBack,
    required this.onHome,
    required this.onRetry,
    super.key,
  });

  final BlockedPage page;
  final VoidCallback onBack;
  final VoidCallback onHome;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bool checkFailed = page.reason == NavigationVerdict.checkFailedReason;
    return _Overlay(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxFormWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: _Medallion(
                    icon: checkFailed ? AppIcons.syncProblem : AppIcons.webBlocked,
                    tone: Tone.neutral,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  liveRegion: true,
                  header: true,
                  child: Text(
                    checkFailed ? 'Não deu para conferir este site' : 'Este site não abre aqui',
                    textAlign: TextAlign.center,
                    style: context.text.headlineSmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  page.domain,
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium?.copyWith(color: context.colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  blockedReasonText(page.reason, page.category),
                  textAlign: TextAlign.center,
                  style: context.text.bodyLarge,
                ),
                if (!checkFailed) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Se você acha que este site deveria abrir, converse com o seu responsável.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                if (checkFailed) ...<Widget>[
                  AppButton.primary(
                    label: 'Tentar de novo',
                    icon: AppIcons.refresh,
                    onPressed: onRetry,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton.tertiary(label: 'Voltar', icon: AppIcons.back, onPressed: onBack),
                ] else ...<Widget>[
                  AppButton.primary(label: 'Voltar', icon: AppIcons.back, onPressed: onBack),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton.tertiary(label: 'Ir para a página inicial', onPressed: onHome),
                ],
              ],
            ),
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
      height: AppSizes.minTapTarget + AppSpacing.lg,
      color: context.colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          AppIconButton(icon: AppIcons.back, tooltip: 'Voltar', onPressed: hasPage ? onBack : null),
          AppIconButton(
            icon: AppIcons.forward,
            tooltip: 'Avançar',
            onPressed: state.canGoForward ? onForward : null,
          ),
          AppIconButton(
            icon: AppIcons.home,
            tooltip: 'Página inicial',
            onPressed: hasPage ? onHome : null,
          ),
          AppIconButton(
            icon: AppIcons.refresh,
            tooltip: 'Recarregar',
            onPressed: hasPage ? onReload : null,
          ),
        ],
      ),
    );
  }
}
