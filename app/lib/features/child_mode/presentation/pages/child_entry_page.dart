import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/feedback_views.dart';
import '../../../device_linking/domain/entities/link_state.dart';
import '../../../device_linking/presentation/bloc/child_link/child_link_bloc.dart';

/// Tela de entrada do modo crianca, mostrada enquanto se descobre se o aparelho esta
/// vinculado. O roteador sai dela assim que a resposta chega.
class ChildEntryPage extends StatefulWidget {
  const ChildEntryPage({super.key});

  @override
  State<ChildEntryPage> createState() => _ChildEntryPageState();
}

class _ChildEntryPageState extends State<ChildEntryPage> {
  @override
  void initState() {
    super.initState();
    context.read<ChildLinkBloc>().add(const ChildLinkLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final bool failed = context.select<ChildLinkBloc, bool>(
      (ChildLinkBloc bloc) => bloc.state.phase == LinkPhase.failed,
    );
    return Scaffold(
      body: SafeArea(
        child: failed
            ? EmptyState(
                icon: Icons.error_outline,
                title: 'Não foi possível abrir o controle parental',
                message: 'O aparelho não respondeu. Tente de novo em instantes.',
                actionLabel: 'Tentar de novo',
                onAction: () => context.read<ChildLinkBloc>().add(const ChildLinkLoadRequested()),
              )
            : const LoadingView(message: 'Abrindo o controle parental...'),
      ),
    );
  }
}
