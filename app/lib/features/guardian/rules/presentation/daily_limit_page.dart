import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/domain/policy.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import 'widgets/duration_picker.dart';
import 'widgets/rule_scaffold.dart';

/// Opcoes de aviso para a crianca, em minutos restantes.
const List<int> _warningOptions = <int>[30, 15, 10, 5, 1];

/// Limite diario de uso: valor exato em horas e minutos, por dia da semana, horario de
/// reinicio da contagem e avisos.
class DailyLimitPage extends StatelessWidget {
  const DailyLimitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RuleEditorScaffold(
      title: 'Limite diário',
      children: (BuildContext context, RuleEditing editing) {
        final DailyLimit limit = editing.draft.dailyLimit;

        void change(DailyLimit Function(DailyLimit current) update) {
          editing.update((Policy policy) => policy.copyWith(dailyLimit: update(policy.dailyLimit)));
        }

        return <Widget>[
          SwitchCard(
            icon: Icons.timer_outlined,
            title: 'Limitar o tempo de uso por dia',
            subtitle: 'Quando o tempo acaba, só as exceções continuam disponíveis.',
            value: limit.enabled,
            onChanged: (bool value) => change((DailyLimit d) => d.copyWith(enabled: value)),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!limit.enabled)
            const NoticeBanner(
              message:
                  'Sem limite diário, o tempo de uso não é restringido. Os horários permitidos, '
                  'os períodos de bloqueio e os apps bloqueados continuam valendo.',
            )
          else ...<Widget>[
            _AmountCard(limit: limit, onChanged: change),
            const SizedBox(height: AppSpacing.md),
            _ResetCard(limit: limit, onChanged: change),
            const SizedBox(height: AppSpacing.md),
            _WarningsCard(limit: limit, onChanged: change),
          ],
        ];
      },
    );
  }
}

typedef _LimitChange = void Function(DailyLimit Function(DailyLimit current) update);

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.limit, required this.onChanged});

  final DailyLimit limit;
  final _LimitChange onChanged;

  Future<void> _pickDefault(BuildContext context) async {
    final int? minutes = await showDurationPicker(
      context,
      title: 'Tempo por dia',
      helper: 'Escolha as horas e os minutos exatos. O máximo é 24h.',
      initialMinutes: limit.minutes,
    );
    if (minutes != null) {
      onChanged((DailyLimit d) => d.copyWith(minutes: minutes));
    }
  }

  Future<void> _pickDay(BuildContext context, int day) async {
    final int? minutes = await showDurationPicker(
      context,
      title: 'Tempo na ${weekdayLong(day)}',
      initialMinutes: limit.minutesFor(day),
    );
    if (minutes != null) {
      onChanged(
        (DailyLimit d) => d.copyWith(perWeekday: <int, int>{...d.perWeekday, day: minutes}),
      );
    }
  }

  void _togglePerWeekday(bool value) {
    onChanged((DailyLimit d) {
      if (!value) {
        return d.copyWith(perWeekday: const <int, int>{});
      }
      return d.copyWith(
        perWeekday: <int, int>{for (int day = 1; day <= 7; day++) day: d.minutesFor(day)},
      );
    });
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
            onChanged: _togglePerWeekday,
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
  const _ResetCard({required this.limit, required this.onChanged});

  final DailyLimit limit;
  final _LimitChange onChanged;

  Future<void> _pick(BuildContext context) async {
    final ({int hour, int minute})? picked = await pickTimeOfDay(
      context,
      hour: limit.resetTime.hour,
      minute: limit.resetTime.minute,
      helpText: 'Reinício da contagem',
    );
    if (picked != null) {
      onChanged((DailyLimit d) => d.copyWith(resetTime: LocalTime(picked.hour, picked.minute)));
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
  const _WarningsCard({required this.limit, required this.onChanged});

  final DailyLimit limit;
  final _LimitChange onChanged;

  void _toggle(int minutes, bool selected) {
    onChanged((DailyLimit d) {
      final Set<int> next = <int>{...d.warnAtMinutes};
      if (selected) {
        next.add(minutes);
      } else {
        next.remove(minutes);
      }
      final List<int> sorted = next.toList()..sort((int a, int b) => b.compareTo(a));
      return d.copyWith(warnAtMinutes: sorted);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool full = limit.warnAtMinutes.length >= 4;
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
              for (final int option in _warningOptions)
                FilterChip(
                  label: Text(formatMinutes(option)),
                  selected: limit.warnAtMinutes.contains(option),
                  onSelected: full && !limit.warnAtMinutes.contains(option)
                      ? null
                      : (bool selected) => _toggle(option, selected),
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
