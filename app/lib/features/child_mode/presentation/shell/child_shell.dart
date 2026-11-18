import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../bloc/child_device_status/child_device_status_bloc.dart';
import '../bloc/child_shell/child_shell_bloc.dart';
import '../services/foreground_tracker.dart';

/// Envolve todas as telas do modo crianca.
///
/// Cuida do que vale para a area inteira: avisar se o app esta em primeiro plano (as
/// consultas periodicas param em segundo plano), religar o servico do agente quando o app
/// volta e levar a pessoa a tela pedida por quem abriu o app (notificacao ou tela de bloqueio
/// nativa).
///
/// Precisa, acima na arvore, do [ChildShellBloc], do [ChildDeviceStatusBloc] e do
/// [ForegroundTracker] (montados pela rota da area, `childShellRoute`).
class ChildShell extends StatefulWidget {
  const ChildShell({required this.location, required this.child, super.key});

  /// Caminho da tela em exibicao.
  final String location;
  final Widget child;

  @override
  State<ChildShell> createState() => _ChildShellState();
}

class _ChildShellState extends State<ChildShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    context.read<ForegroundTracker>().update(foreground: foreground);
    if (state == AppLifecycleState.resumed) {
      context.read<ChildDeviceStatusBloc>().add(const ChildDeviceStatusAppResumed());
    }
  }

  void _open(ChildLaunchDestination destination) {
    final GoRouter router = GoRouter.of(context);
    switch (destination) {
      case ChildLaunchDestination.home:
        if (widget.location != ChildPaths.home) {
          router.go(ChildPaths.home);
        }
      case ChildLaunchDestination.guardianArea:
        _push(router, ChildPaths.guardianArea);
      case ChildLaunchDestination.permissions:
        _push(router, ChildPaths.permissions);
    }
    context.read<ChildShellBloc>().add(const ChildShellLaunchActionHandled());
  }

  /// Abre [path] por cima da tela inicial, para o voltar levar a ela.
  void _push(GoRouter router, String path) {
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
    return BlocListener<ChildShellBloc, ChildShellState>(
      listenWhen: (ChildShellState previous, ChildShellState current) {
        return current.destination != null && current != previous;
      },
      listener: (BuildContext context, ChildShellState state) {
        final ChildLaunchDestination destination = state.destination!;
        // A tela inicial so existe depois que o roteador reagir a mudanca de fase.
        WidgetsBinding.instance.addPostFrameCallback((Duration timestamp) {
          if (mounted) {
            _open(destination);
          }
        });
      },
      child: widget.child,
    );
  }
}
