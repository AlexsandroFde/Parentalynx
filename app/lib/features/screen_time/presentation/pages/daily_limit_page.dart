import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/duration_picker.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/widgets/rule_editor_scaffold.dart';
import '../../domain/services/daily_limit_editing.dart';
import '../bloc/screen_time/screen_time_bloc.dart';

/// Limite diario de uso: valor exato em horas e minutos, por dia da semana, horario de
/// reinicio da contagem e avisos.
///
/// Espera um [ScreenTimeBloc] acima na arvore, ja iniciado para [device].
class DailyLimitPage extends StatelessWidget {
  const DailyLimitPage({required this.device, super.key});

  final ChildDevice device;

  @override
  Widget build(BuildContext context) {
    final ScreenTimeBloc bloc = context.read<ScreenTimeBloc>();
    return RuleEditorScaffold<ScreenTimeBloc, DailyLimit>(
      title: 'Limite diário',
      device: device,
      onSave: () => bloc.add(const ScreenTimeSaveRequested()),
      onDiscard: () => bloc.add(const ScreenTimeDiscardRequested()),
      onRetry: () => bloc.add(ScreenTimeStarted(device.id)),
      children: (BuildContext context, DailyLimit limit) {
        return <Widget>[
          SwitchCard(
            icon: Icons.timer_outlined,
            title: 'Limitar o tempo de uso por dia',
            subtitle: 'Quando o tempo acaba, só as exceções continuam disponíveis.',
            value: limit.enabled,
            onChanged: (bool value) => bloc.add(DailyLimitEnabledChanged(value)),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!limit.enabled)
            const NoticeBanner(
              message:
                  'Sem limite diário, o tempo de uso não é restringido. Os horários permitidos, '
                  'os períodos de bloqueio e os apps bloqueados continuam valendo.',
            )
          else ...<Widget>[
            _AmountCard(limit: limit, bloc: bloc),
            const SizedBox(height: AppSpacing.md),
            _ResetCard(limit: limit, bloc: bloc),
            const SizedBox(height: AppSpacing.md),
            _WarningsCard(limit: limit, bloc: bloc),
          ],
        ];
      },
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.limit, required this.bloc});

  final DailyLimit limit;
  final ScreenTimeBloc bloc;

  Future<void> _pickDefault(BuildContext context) async {
    final int? minutes = await showDurationPicker(
      context,
      title: 'Tempo por dia',
      helper: 'Escolha as horas e os minutos exatos. O máximo é 24h.',
      initialMinutes: limit.minutes,
    );
    if (minutes != null) {
      bloc.add(DailyLimitMinutesChanged(minutes));
    }
  }

  Future<void> _pickDay(BuildContext context, int day) async {
    final int? minutes = await showDurationPicker(
      context,
      title: 'Tempo na ${weekdayLong(day)}',
      initialMinutes: limit.minutesFor(day),
    );
    if (minutes != null) {
      bloc.add(DailyLimitWeekdayMinutesChanged(weekday: day, minutes: minutes));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool perWeekday = !limit.sameEveryDay;
    return SectionCard(
      title: 'Tempo por dia',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!perWeekday) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    formatMinutes(limit.minutes),
                    key: const ValueKey<String>('daily-limit-value'),
                    style: theme.textTheme.displaySmall,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _pickDefault(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Alterar'),
                ),
              ],
            ),
            if (limit.minutes == 0) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              const NoticeBanner(
                tone: Tone.warning,
                message:
                    'Com 0min não há tempo livre: só os apps marcados como exceção poderão '
                    'ser usados.',
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
          ],
          SwitchRow(
            title: 'Limite diferente por dia da semana',
            subtitle: 'Por exemplo, mais tempo no sábado e no domingo.',
            value: perWeekday,
            onChanged: (bool value) => bloc.add(DailyLimitPerWeekdayToggled(value)),
          ),
          if (perWeekday) ...<Widget>[
            const Divider(),
            for (int day = 1; day <= 7; day++)
              _WeekdayRow(
                day: day,
                minutes: limit.minutesFor(day),
                onTap: () => _pickDay(context, day),
              ),
          ],
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.day, required this.minutes, required this.onTap});

  final int day;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = weekdayLong(day);
    return InkWell(
      key: ValueKey<String>('weekday-limit-$day'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${name[0].toUpperCase()}${name.substring(1)}',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            Text(formatMinutes(minutes), style: theme.textTheme.titleMedium),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.edit_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ResetCard extends StatelessWidget {
  const _ResetCard({required this.limit, required this.bloc});

  final DailyLimit limit;
  final ScreenTimeBloc bloc;

  Future<void> _pick(BuildContext context) async {
    final ({int hour, int minute})? picked = await pickTimeOfDay(
      context,
      hour: limit.resetTime.hour,
      minute: limit.resetTime.minute,
      helpText: 'Reinício da contagem',
    );
    if (picked != null) {
      bloc.add(DailyLimitResetTimeChanged(LocalTime(picked.hour, picked.minute)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool midnight = limit.resetTime == LocalTime.midnight;
    return SectionCard(
      title: 'Reinício da contagem',
      subtitle: 'Horário em que o tempo do dia volta ao início.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Todos os dias às ${limit.resetTime}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton(onPressed: () => _pick(context), child: const Text('Alterar')),
            ],
          ),
          if (!midnight)
            Text(
              'O uso feito depois da meia-noite e antes das ${limit.resetTime} ainda conta no '
              'dia anterior.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.limit, required this.bloc});

  final DailyLimit limit;
  final ScreenTimeBloc bloc;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SectionCard(
      title: 'Avisos para a criança',
      subtitle: 'O aparelho avisa quando faltar este tempo para o limite.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final int option in DailyLimitWarnings.options)
                FilterChip(
                  label: Text(formatMinutes(option)),
                  selected: limit.warnAtMinutes.contains(option),
                  onSelected: limit.canEnableWarning(option)
                      ? (bool selected) {
                          bloc.add(DailyLimitWarningToggled(minutes: option, enabled: selected));
                        }
                      : null,
                ),
            ],
          ),
          if (limit.warnAtMinutes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Sem avisos, o bloqueio acontece de uma vez quando o tempo acaba.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
