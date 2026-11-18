import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/feedback_views.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';

/// Monta uma pagina de regras para o aparelho em foco, ou explica que nao ha aparelho
/// vinculado.
///
/// O BLoC da pagina deve ser criado dentro de [builder] com uma chave pelo identificador do
/// aparelho, para recomecar quando o responsavel escolhe outro aparelho.
class SelectedDeviceGate extends StatelessWidget {
  const SelectedDeviceGate({required this.title, required this.builder, super.key});

  final String title;
  final Widget Function(BuildContext context, ChildDevice device) builder;

  @override
  Widget build(BuildContext context) {
    final ChildDevice? device = context.select<DevicesBloc, ChildDevice?>(
      (DevicesBloc bloc) => bloc.state.selected,
    );
    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const EmptyState(
          icon: Icons.phonelink_off_outlined,
          title: 'Nenhum aparelho vinculado',
          message: 'Vincule o aparelho da criança para definir as regras.',
        ),
      );
    }
    return builder(context, device);
  }
}
