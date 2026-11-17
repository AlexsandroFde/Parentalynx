import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/platform/native_providers.dart';
import '../../../shared/widgets/feedback_views.dart';
import '../agent/data/child_agent_repository.dart';
import '../agent/presentation/child_session.dart';
import '../child_paths.dart';

/// Envolve todas as telas do modo crianca.
///
/// Cuida do que vale para a area inteira: manter o servico do agente rodando quando o app
/// abre, pausar as consultas periodicas com o app em segundo plano e tratar as acoes pedidas
/// por quem abriu o app (notificacao ou tela de bloqueio nativa).
class ChildShell extends ConsumerStatefulWidget {
  const ChildShell({required this.location, required this.child, super.key});

  /// Caminho da tela em exibicao.
  final String location;
  final Widget child;

  @override
  ConsumerState<ChildShell> createState() => _ChildShellState();
}

class _ChildShellState extends ConsumerState<ChildShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((Duration timestamp) {
      if (mounted) {
        _ensureAgentRunning();
        _handlePendingAction();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool foreground =
        state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
    ref.read(childForegroundProvider.notifier).set(foreground: foreground);
    if (state == AppLifecycleState.resumed) {
      _ensureAgentRunning();
    }
  }

  bool get _linked {
    final ChildLinkPhase phase = ref.read(childLinkProvider);
    return phase == ChildLinkPhase.ready || phase == ChildLinkPhase.onboarding;
  }

  void _ensureAgentRunning() {
    if (_linked) {
      unawaited(_startAgent(ref.read(childAgentRepositoryProvider)));
    }
  }

  static Future<void> _startAgent(ChildAgentRepository agent) async {
    try {
      await agent.ensureRunning();
    } on AppFailure {
      // O agente tem outros caminhos para voltar (servico de acessibilidade, boot, tarefa
      // periodica). Uma falha aqui nao impede o uso da tela.
    }
  }

  /// Trata a acao pedida por quem abriu o app, quando o aparelho ja esta vinculado.
  void _handlePendingAction() {
    final String? action = ref.read(launchActionProvider);
    if (action == null) {
      return;
    }
    final ChildLinkPhase phase = ref.read(childLinkProvider);
    if (phase == ChildLinkPhase.unknown || phase == ChildLinkPhase.onboarding) {
      // Ainda carregando ou configurando: a acao espera a tela inicial ficar disponivel.
      return;
    }
    ref.read(launchActionProvider.notifier).consume();
    if (phase != ChildLinkPhase.ready) {
      return;
    }
    final GoRouter router = GoRouter.of(context);
    switch (action) {
      case 'guardian_area':
        _open(router, ChildPaths.guardianArea);
      case 'permissions':
        _open(router, ChildPaths.permissions);
      case 'child_home':
        if (widget.location != ChildPaths.home) {
          router.go(ChildPaths.home);
        }
      default:
        // Acoes de outro modo (por exemplo `alerts`) nao se aplicam aqui.
        break;
    }
  }

  void _open(GoRouter router, String path) {
    if (widget.location == path) {
      return;
    }
    if (widget.location != ChildPaths.home) {
      router.go(ChildPaths.home);
    }
    unawaited(router.push<void>(path));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(launchActionProvider, (String? previous, String? next) {
      if (next != null) {
        _handlePendingAction();
      }
    });
    ref.listen<ChildLinkPhase>(childLinkProvider, (ChildLinkPhase? previous, ChildLinkPhase next) {
      if (next == ChildLinkPhase.ready || next == ChildLinkPhase.onboarding) {
        _ensureAgentRunning();
      }
      // A tela inicial so existe depois que o roteador reagir a mudanca de fase.
      WidgetsBinding.instance.addPostFrameCallback((Duration timestamp) {
        if (mounted) {
          _handlePendingAction();
        }
      });
    });
    return widget.child;
  }
}

/// Tela de entrada do modo crianca, mostrada enquanto se descobre se o aparelho esta
/// vinculado. O roteador sai dela assim que a resposta chega.
class ChildEntryPage extends ConsumerStatefulWidget {
  const ChildEntryPage({super.key});

  @override
  ConsumerState<ChildEntryPage> createState() => _ChildEntryPageState();
}

class _ChildEntryPageState extends ConsumerState<ChildEntryPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) {
        return ref.read(childLinkProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ChildLinkPhase phase = ref.watch(childLinkProvider);
    return Scaffold(
      body: SafeArea(
        child: phase == ChildLinkPhase.failed
            ? EmptyState(
                icon: Icons.error_outline,
                title: 'Não foi possível abrir o controle parental',
                message: 'O aparelho não respondeu. Tente de novo em instantes.',
                actionLabel: 'Tentar de novo',
                onAction: () => ref.read(childLinkProvider.notifier).load(),
              )
            : const LoadingView(message: 'Abrindo o controle parental...'),
      ),
    );
  }
}
