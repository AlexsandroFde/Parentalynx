import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../app/theme/app_theme.dart';
import '../../../devices/domain/device.dart';
import '../../../devices/presentation/devices_providers.dart';

/// Seletor do aparelho em foco. So aparece quando ha mais de um aparelho ativo.
class DeviceSelector extends ConsumerWidget {
  const DeviceSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Device> devices = ref.watch(activeDevicesProvider);
    final Device? selected = ref.watch(selectedDeviceProvider);
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
              for (final Device device in devices)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    avatar: const Icon(Icons.smartphone, size: 18),
                    label: Text(device.displayName),
                    selected: device.id == selected?.id,
                    onSelected: (_) {
                      ref.read(selectedDeviceIdProvider.notifier).select(device.id);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
