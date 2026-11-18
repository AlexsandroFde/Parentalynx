import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/child_device.dart';
import '../bloc/devices/devices_bloc.dart';

/// Seletor do aparelho em foco no painel, nas regras e nos relatorios. So aparece quando ha
/// mais de um aparelho ativo.
///
/// As opcoes quebram linha em vez de rolar de lado (todas ficam visiveis, inclusive com fonte
/// ampliada). Quando duas criancas tem o mesmo nome, o modelo do aparelho desfaz a duvida.
class DeviceSelector extends StatelessWidget {
  const DeviceSelector({super.key});

  static String _label(ChildDevice device, List<ChildDevice> all) {
    final bool repeated =
        all.where((ChildDevice other) => other.displayName == device.displayName).length > 1;
    final String model = device.model.isEmpty ? device.deviceName : device.model;
    return repeated && model.isNotEmpty ? '${device.displayName} · $model' : device.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final DevicesState state = context.watch<DevicesBloc>().state;
    final List<ChildDevice> devices = state.active;
    if (devices.length < 2) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Semantics(
        label: 'Aparelho em foco',
        container: true,
        explicitChildNodes: true,
        child: AppChoiceChips<String>(
          choices: <AppChoice<String>>[
            for (final ChildDevice device in devices)
              AppChoice<String>(
                value: device.id,
                label: _label(device, devices),
                icon: AppIcons.device,
              ),
          ],
          selected: state.selected?.id,
          onSelected: (String id) => context.read<DevicesBloc>().add(DeviceSelected(id)),
        ),
      ),
    );
  }
}
