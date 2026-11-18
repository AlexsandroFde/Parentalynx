import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/child_device.dart';
import '../bloc/devices/devices_bloc.dart';

/// Seletor do aparelho em foco. So aparece quando ha mais de um aparelho ativo.
class DeviceSelector extends StatelessWidget {
  const DeviceSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final DevicesState state = context.watch<DevicesBloc>().state;
    final List<ChildDevice> devices = state.active;
    final ChildDevice? selected = state.selected;
    if (devices.length < 2) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        label: 'Escolher o aparelho',
        container: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final ChildDevice device in devices)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    avatar: const Icon(Icons.smartphone, size: 18),
                    label: Text(device.displayName),
                    selected: device.id == selected?.id,
                    onSelected: (_) => context.read<DevicesBloc>().add(DeviceSelected(device.id)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
