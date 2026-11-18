import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../../device_linking/domain/entities/link_state.dart';
import '../../../device_linking/presentation/bloc/child_link/child_link_bloc.dart';
import '../widgets/child_problem_view.dart';

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
        child: StateSwitcher(
          alignment: Alignment.center,
          child: failed
              ? KeyedSubtree(
                  key: const ValueKey<String>('falhou'),
                  child: ChildProblemView(
                    onRetry: () =>
                        context.read<ChildLinkBloc>().add(const ChildLinkLoadRequested()),
                  ),
                )
              : const KeyedSubtree(
                  key: ValueKey<String>('abrindo'),
                  child: LoadingState(message: 'Abrindo o controle parental...'),
                ),
        ),
      ),
    );
  }
}
