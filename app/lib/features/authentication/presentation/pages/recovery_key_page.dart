import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../bloc/auth/auth_bloc.dart';
import '../widgets/recovery_key_view.dart';

/// Mostra a chave de recuperacao recem-gerada e so deixa continuar depois que a pessoa
/// confirma que guardou. A chave nao e mostrada de novo.
class RecoveryKeyPage extends StatelessWidget {
  const RecoveryKeyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthState state = context.watch<AuthBloc>().state;
    final String? key = state is AuthReady ? state.pendingRecoveryKey : null;
    if (key == null) {
      // O roteador ja esta saindo desta tela.
      return const Scaffold(body: LoadingState());
    }
    return PopScope(
      canPop: false,
      child: RecoveryKeyView(
        recoveryKey: key,
        onDone: () => context.read<AuthBloc>().add(const AuthRecoveryKeyAcknowledged()),
      ),
    );
  }
}
