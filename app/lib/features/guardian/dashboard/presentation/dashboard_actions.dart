import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/domain/policy.dart';
import '../../auth/presentation/elevation.dart';
import '../../devices/data/devices_repository.dart';
import '../../devices/domain/device.dart';
import '../../devices/presentation/devices_providers.dart';
import '../../rules/presentation/widgets/duration_picker.dart';
import '../data/dashboard_data.dart';

/// Executa um comando do responsavel (tempo extra, pausa, suspensao) com confirmacao de senha
/// quando necessario, e atualiza o painel com a politica devolvida.
Future<bool> runDeviceCommand(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
  Future<DevicePolicy> Function(DevicesRepository repository) command, {
  required String successMessage,
}) async {
  final DevicePolicy? policy = await guardedAction<DevicePolicy>(
    context,
    ref,
    () => command(ref.read(devicesRepositoryProvider)),
    successMessage: successMessage,
  );
  if (policy == null || !context.mounted) {
    return false;
  }
  ref.read(devicePolicySnapshotProvider(deviceId).notifier).set(policy);
  unawaited(ref.read(devicesProvider.notifier).refresh());
  return true;
}

/// Concede minutos extras para hoje.
Future<void> grantExtraTime(BuildContext context, WidgetRef ref, Device device, int minutes) {
  return runDeviceCommand(
    context,
    ref,
    device.id,
    (DevicesRepository repository) => repository.grantExtraTime(device.id, minutes: minutes),
    successMessage: '${formatMinutes(minutes)} a mais enviados para ${device.displayName}.',
  );
}

/// Pede um valor personalizado de tempo extra e o concede.
Future<void> grantCustomExtraTime(BuildContext context, WidgetRef ref, Device device) async {
  final int? minutes = await showDurationPicker(
    context,
    title: 'Tempo extra para hoje',
    helper: 'Soma ao limite de hoje. Amanhã o limite volta ao normal.',
    initialMinutes: 45,
    minMinutes: 1,
    maxMinutes: 720,
    presets: const <int>[10, 20, 45, 90, 120],
  );
  if (minutes != null && context.mounted) {
    await grantExtraTime(context, ref, device, minutes);
  }
}

/// Pergunta por quanto tempo pausar e bloqueia o aparelho agora.
Future<void> pauseDevice(BuildContext context, WidgetRef ref, Device device) async {
  final _PauseChoice? choice = await showDialog<_PauseChoice>(
    context: context,
    builder: (BuildContext context) {
      return SimpleDialog(
        title: Text('Pausar o aparelho de ${device.displayName}'),
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Só as exceções continuam funcionando. Chamadas de emergência nunca são '
              'bloqueadas.',
            ),
          ),
          for (final _PauseChoice option in _PauseChoice.values)
            SimpleDialogOption(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              onPressed: () => Navigator.of(context).pop(option),
              child: Text(option.label),
            ),
        ],
      );
    },
  );
  if (choice == null || !context.mounted) {
    return;
  }
  final int? minutes = choice.minutes;
  final int? until = minutes == null
      ? null
      : DateTime.now().add(Duration(minutes: minutes)).millisecondsSinceEpoch;
  await runDeviceCommand(
    context,
    ref,
    device.id,
    (DevicesRepository repository) => repository.lock(device.id, until: until),
    successMessage: 'Pausa enviada para ${device.displayName}.',
  );
}

enum _PauseChoice {
  thirty('Por 30 minutos', 30),
  hour('Por 1 hora', 60),
  twoHours('Por 2 horas', 120),
  untilResumed('Até eu retomar', null);

  const _PauseChoice(this.label, this.minutes);

  final String label;
  final int? minutes;
}

/// Encerra a pausa manual.
Future<void> resumeDevice(BuildContext context, WidgetRef ref, Device device) {
  return runDeviceCommand(
    context,
    ref,
    device.id,
    (DevicesRepository repository) => repository.unlock(device.id),
    successMessage: 'Retomada enviada para ${device.displayName}.',
  );
}

/// Encerra a suspensao de regras.
Future<void> endSuspension(BuildContext context, WidgetRef ref, Device device) {
  return runDeviceCommand(
    context,
    ref,
    device.id,
    (DevicesRepository repository) => repository.clearSuspension(device.id),
    successMessage: 'As regras voltam a valer para ${device.displayName}.',
  );
}

/// Abre a folha de suspensao temporaria de regras e envia o comando.
Future<void> suspendRules(BuildContext context, WidgetRef ref, Device device) async {
  final ({int minutes, List<SuspensionScope> scopes})? choice =
      await showModalBottomSheet<({int minutes, List<SuspensionScope> scopes})>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (BuildContext context) => const _SuspendSheet(),
      );
  if (choice == null || !context.mounted) {
    return;
  }
  await runDeviceCommand(context, ref, device.id, (DevicesRepository repository) {
    return repository.suspend(device.id, minutes: choice.minutes, scopes: choice.scopes);
  }, successMessage: 'Regras suspensas por ${formatMinutes(choice.minutes)}.');
}

class _SuspendSheet extends StatefulWidget {
  const _SuspendSheet();

  @override
  State<_SuspendSheet> createState() => _SuspendSheetState();
}

class _SuspendSheetState extends State<_SuspendSheet> {
  static const List<int> _durations = <int>[30, 60, 120, 240];

  int _minutes = 60;
  final Set<SuspensionScope> _scopes = <SuspensionScope>{
    SuspensionScope.dailyLimit,
    SuspensionScope.schedules,
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Suspender regras', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'As regras escolhidas deixam de valer por um tempo e voltam sozinhas. O tempo '
            'usado durante a suspensão do limite não consome a cota do dia.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Por quanto tempo', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final int option in _durations)
                ChoiceChip(
                  label: Text(formatMinutes(option)),
                  selected: _minutes == option,
                  onSelected: (_) => setState(() => _minutes = option),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('O que suspender', style: theme.textTheme.labelLarge),
          for (final SuspensionScope scope in SuspensionScope.values)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(scope.label),
              value: _scopes.contains(scope),
              onChanged: (bool? checked) => setState(() {
                if (checked ?? false) {
                  _scopes.add(scope);
                } else {
                  _scopes.remove(scope);
                }
              }),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _scopes.isEmpty
                ? null
                : () => Navigator.of(context).pop((
                    minutes: _minutes,
                    scopes: SuspensionScope.values.where(_scopes.contains).toList(),
                  )),
            child: const Text('Suspender'),
          ),
        ],
      ),
    );
  }
}
