import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/time/formatters.dart';
import '../../../../../shared/theme/app_theme.dart';
import '../../../../../shared/widgets/form_widgets.dart';
import '../../../../child_device/domain/entities/child_device.dart';
import '../../../domain/entities/active_commands.dart';
import '../../bloc/dashboard/guardian_dashboard_bloc.dart';
import '../../dialogs/dashboard_command_dialogs.dart';

/// Acoes rapidas enviadas na hora ao aparelho: tempo extra, pausa e suspensao de regras.
///
/// Despacha os comandos ao [GuardianDashboardBloc] da arvore.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({required this.device, required this.commands, super.key});

  final ChildDevice device;
  final ActiveCommands commands;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int extraToday = commands.extraMinutesToday;
    final GuardianDashboardBloc bloc = context.read<GuardianDashboardBloc>();
    return SectionCard(
      title: 'Ações rápidas',
      subtitle: 'Enviadas na hora ao aparelho de ${device.displayName}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Tempo extra para hoje', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final int minutes in const <int>[15, 30, 60])
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(formatMinutes(minutes)),
                  onPressed: () => bloc.add(DashboardExtraTimeRequested(minutes)),
                ),
              ActionChip(
                label: const Text('Outro valor'),
                onPressed: () async {
                  final int? minutes = await showCustomExtraTimePicker(context);
                  if (minutes != null) {
                    bloc.add(DashboardExtraTimeRequested(minutes));
                  }
                },
              ),
            ],
          ),
          if (extraToday > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Hoje já foram concedidos ${formatMinutes(extraToday)} extras.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          // Um botao por linha: os rotulos cabem inteiros mesmo com fonte grande.
          if (commands.paused)
            FilledButton.icon(
              onPressed: () => bloc.add(const DashboardResumeRequested()),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Retomar'),
            )
          else
            FilledButton.tonalIcon(
              onPressed: () async {
                final PauseChoice? choice = await showPauseChoiceDialog(context, device);
                if (choice != null) {
                  bloc.add(DashboardPauseRequested(duration: choice.duration));
                }
              },
              icon: const Icon(Icons.pause),
              label: const Text('Pausar agora'),
            ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: commands.suspended
                ? () => bloc.add(const DashboardSuspensionEndRequested())
                : () async {
                    final SuspensionChoice? choice = await showSuspendRulesSheet(context);
                    if (choice != null) {
                      bloc.add(
                        DashboardSuspendRequested(minutes: choice.minutes, scopes: choice.scopes),
                      );
                    }
                  },
            icon: Icon(commands.suspended ? Icons.play_circle_outline : Icons.pause_circle_outline),
            label: Text(commands.suspended ? 'Encerrar suspensão' : 'Suspender regras'),
          ),
        ],
      ),
    );
  }
}
