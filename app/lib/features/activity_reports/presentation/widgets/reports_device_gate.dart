import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/feedback_views.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../child_device/presentation/bloc/devices/devices_bloc.dart';

/// Monta uma pagina de detalhe dos relatorios para o aparelho em foco, ou explica que nao ha
/// aparelho vinculado.
///
/// O BLoC da pagina deve ser criado dentro de [builder] com uma chave pelo identificador do
/// aparelho, para recomecar quando o aparelho em foco muda.
class ReportsDeviceGate extends StatelessWidget {
  const ReportsDeviceGate({
    required this.title,
    required this.icon,
    required this.builder,
    super.key,
  });

  /// Titulo da pagina, mostrado tambem quando nao ha aparelho.
  final String title;
  final IconData icon;
  final Widget Function(BuildContext context, ChildDevice device) builder;

  @override
  Widget build(BuildContext context) {
    final ChildDevice? device = context.select<DevicesBloc, ChildDevice?>(
      (DevicesBloc bloc) => bloc.state.selected,
    );
    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: EmptyState(icon: icon, title: 'Nenhum aparelho vinculado'),
      );
    }
    return builder(context, device);
  }
}
