import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../bloc/auth/auth_bloc.dart';

/// Avisa o [AuthBloc] quando o app vai para o segundo plano e quando volta, para o painel
/// bloquear depois do tempo escolhido.
///
/// Fica em volta das telas do painel aberto: com o painel bloqueado ou sem sessao nao ha o
/// que bloquear.
class SessionLifecycleListener extends StatefulWidget {
  const SessionLifecycleListener({required this.child, super.key});

  final Widget child;

  @override
  State<SessionLifecycleListener> createState() => _SessionLifecycleListenerState();
}

class _SessionLifecycleListenerState extends State<SessionLifecycleListener> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onStateChange: _onStateChange);
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  void _onStateChange(AppLifecycleState state) {
    final AuthBloc bloc = context.read<AuthBloc>();
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        bloc.add(const AuthAppPaused());
      case AppLifecycleState.resumed:
        bloc.add(const AuthAppResumed());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
