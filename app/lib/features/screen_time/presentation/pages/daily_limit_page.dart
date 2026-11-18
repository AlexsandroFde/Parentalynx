import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/texts/describe_days.dart';
import '../../../device_policy/presentation/widgets/rule_editor_scaffold.dart';
import '../../domain/services/daily_limit_editing.dart';
import '../bloc/screen_time/screen_time_bloc.dart';
import '../texts/screen_time_texts.dart';

/// Valores prontos para o tempo por dia (atalhos; o valor exato continua no seletor).
const List<int> _limitPresets = <int>[60, 120, 150, 180];

const List<HelpTopic> _limitHelp = <HelpTopic>[
  HelpTopic(
    title: 'O que conta no limite?',
    body:
        'Conta o tempo com a tela ligada nos apps permitidos. Ligações, funções essenciais do '
        'sistema e as exceções que não descontam do limite ficam de fora.',
  ),
  HelpTopic(
    title: 'O que acontece quando o tempo acaba?',
    body:
        'O celular fica bloqueado até o próximo reinício da contagem. Continuam funcionando as '
        'exceções, as ligações e as funções essenciais. A criança pode pedir mais tempo, e você '
        'responde em Alertas.',
  ),
  HelpTopic(
    title: 'E o tempo extra?',
    body:
        'O tempo extra que você concede no painel ou ao aprovar um pedido vale só para o dia e '
        'é somado ao limite. O limite dos outros dias não muda.',
  ),
];

/// Limite diario de uso: valor exato em horas e minutos (com atalhos), por dia da semana,
/// horario de reinicio da contagem e avisos para a crianca.
///
/// Espera um [ScreenTimeBloc] acima na arvore, ja iniciado para [device].
class DailyLimitPage extends StatelessWidget {
  const DailyLimitPage({required this.device, super.key});

  final ChildDevice device;

  @override
  Widget build(BuildContext context) {
    final ScreenTimeBloc bloc = context.read<ScreenTimeBloc>();
    final String name = device.displayName;
    return RuleEditorScaffold<ScreenTimeBloc, DailyLimit>(
      title: 'Limite diário',
      description: 'Quanto tempo $name pode usar o celular por dia.',
      device: device,
      helpTopics: _limitHelp,
      onSave: () => bloc.add(const ScreenTimeSaveRequested()),
      onDiscard: () => bloc.add(const ScreenTimeDiscardRequested()),
      onRetry: () => bloc.add(ScreenTimeStarted(device.id)),
      onRestoreRejected: () => bloc.add(const ScreenTimeRejectedChangesRestored()),
      children: (BuildContext context, DailyLimit limit) {
        return <Widget>[
          AppListGroup(
            children: <Widget>[
              AppSwitchRow(
                icon: AppIcons.dailyLimit,
                title: 'Limitar o tempo de uso por dia',
                subtitle: 'Quando o tempo acaba, só as exceções continuam funcionando.',
                value: limit.enabled,
                onChanged: (bool value) => bloc.add(DailyLimitEnabledChanged(value)),
              ),
            ],
          ),
          if (!limit.enabled) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            const AppBanner(
              tone: Tone.neutral,
              message:
                  'Sem limite diário, o tempo de uso não é restringido. Os horários '
                  'permitidos, os períodos de bloqueio e os apps bloqueados continuam valendo.',
            ),
          ] else ...<Widget>[
            const SectionGap(),
            if (limit.sameEveryDay) ...<Widget>[
              _AmountSection(limit: limit, bloc: bloc),
              const SizedBox(height: AppSpacing.lg),
            ],
            _WeekdaysSection(limit: limit, bloc: bloc),
            const SectionGap(),
            _ResetSection(limit: limit, bloc: bloc),
            const SectionGap(),
            _WarningsSection(limit: limit, bloc: bloc, childName: name),
          ],
        ];
      },
    );
  }
}

class _AmountSection extends StatelessWidget {
  const _AmountSection({required this.limit, required this.bloc});

  final DailyLimit limit;
  final ScreenTimeBloc bloc;

  Future<void> _pick(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    return AppSection(
      title: 'Tempo por dia',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: MergeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                formatMinutes(limit.minutes),
                                key: const ValueKey<String>('daily-limit-value'),
                                style: context.textStyles.metricLarge,
                              ),
                            ),
                            Text('todos os dias', style: context.text.bodySmall),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    AppButton.secondary(
                      label: 'Alterar tempo',
                      icon: AppIcons.edit,
                      size: AppButtonSize.compact,
                      onPressed: () => _pick(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Atalhos', style: context.text.labelMedium),
                const SizedBox(height: AppSpacing.sm),
                AppChoiceChips<int>(
                  choices: <AppChoice<int>>[
                    for (final int minutes in _limitPresets)
                      AppChoice<int>(value: minutes, label: formatMinutes(minutes)),
                  ],
                  selected: _limitPresets.contains(limit.minutes) ? limit.minutes : null,
                  onSelected: (int minutes) => bloc.add(DailyLimitMinutesChanged(minutes)),
                ),
              ],
            ),
          ),
          if (limit.minutes == 0) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const AppBanner(
              tone: Tone.warning,
              title: 'Sem tempo livre',
              message:
                  'Com 0min, só os apps marcados como exceção poderão ser usados. As ligações '
                  'continuam funcionando.',
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekdaysSection extends StatelessWidget {
  const _WeekdaysSection({required this.limit, required this.bloc});

  final DailyLimit limit;
  final ScreenTimeBloc bloc;

  Future<void> _pickDay(BuildContext context, int day) async {
    final int? minutes = await showDurationPicker(
      context,
      title: 'Tempo na ${weekdayLong(day)}',
      helper: 'Vale para toda ${weekdayLong(day)}, até você mudar de novo.',
      initialMinutes: limit.minutesFor(day),
    );
    if (minutes != null) {
      bloc.add(DailyLimitWeekdayMinutesChanged(weekday: day, minutes: minutes));
    }
  }

  void _toggle(BuildContext context, bool perWeekday) {
    final Map<int, int> before = <int, int>{
      for (int day = 1; day <= 7; day++) day: limit.minutesFor(day),
    };
    bloc.add(DailyLimitPerWeekdayToggled(perWeekday));
    final bool losesValues = before.values.any((int minutes) => minutes != limit.minutes);
    if (perWeekday || !losesValues) {
      return;
    }
    // Voltar ao mesmo tempo todos os dias troca os valores de cada dia: da para desfazer.
    showAppSnackBar(
      context,
      'Agora vale ${formatMinutes(limit.minutes)} todos os dias.',
      actionLabel: 'Desfazer',
      onAction: () {
        bloc.add(const DailyLimitPerWeekdayToggled(true));
        before.forEach((int day, int minutes) {
          bloc.add(DailyLimitWeekdayMinutesChanged(weekday: day, minutes: minutes));
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool perWeekday = !limit.sameEveryDay;
    return AppListGroup(
      footer: perWeekday ? weekLimitsSummary(limit) : null,
      children: <Widget>[
        AppSwitchRow(
          icon: AppIcons.calendar,
          title: 'Tempo diferente em alguns dias',
          subtitle: 'Por exemplo, mais tempo no sábado e no domingo.',
          value: perWeekday,
          onChanged: (bool value) => _toggle(context, value),
        ),
        if (perWeekday)
          for (int day = 1; day <= 7; day++)
            AppListRow(
              key: ValueKey<String>('weekday-limit-$day'),
              title: capitalizeFirst(weekdayLong(day)),
              titleStyle: context.text.bodyLarge,
              trailing: Text(
                formatMinutes(limit.minutesFor(day)),
                style: context.textStyles.metricSmall,
              ),
              showChevron: true,
              onTap: () => _pickDay(context, day),
            ),
      ],
    );
  }
}

class _ResetSection extends StatelessWidget {
  const _ResetSection({required this.limit, required this.bloc});

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
    final bool midnight = limit.resetTime == LocalTime.midnight;
    return AppSection(
      title: 'Reinício da contagem',
      child: AppListGroup(
        footer: midnight
            ? 'O tempo do dia volta ao início à meia-noite.'
            : 'O uso entre 00:00 e ${limit.resetTime} ainda conta no dia anterior.',
        children: <Widget>[
          AppListRow(
            leading: const AppIconTile(icon: AppIcons.reset),
            title: 'Horário de reinício',
            subtitle: 'Todos os dias',
            trailing: Text('${limit.resetTime}', style: context.textStyles.metricSmall),
            showChevron: true,
            onTap: () => _pick(context),
          ),
        ],
      ),
    );
  }
}

class _WarningsSection extends StatelessWidget {
  const _WarningsSection({required this.limit, required this.bloc, required this.childName});

  final DailyLimit limit;
  final ScreenTimeBloc bloc;
  final String childName;

  @override
  Widget build(BuildContext context) {
    final List<int> selected = limit.warnAtMinutes;
    final int smallestLimit = <int>[for (int day = 1; day <= 7; day++) limit.minutesFor(day)]
        .reduce((int a, int b) => a < b ? a : b);
    final bool tooEarly =
        smallestLimit > 0 && selected.any((int minutes) => minutes >= smallestLimit);
    final bool full = selected.length >= DailyLimitWarnings.maxWarnings;
    final String helper = selected.isEmpty
        ? 'Sem avisos, o bloqueio acontece de uma vez quando o tempo acaba.'
        : full
        ? 'Você escolheu ${DailyLimitWarnings.maxWarnings} avisos, o máximo. Desmarque um para '
              'trocar.'
        : 'Escolha até ${DailyLimitWarnings.maxWarnings} avisos.';
    return AppSection(
      title: 'Avisos para $childName',
      subtitle: 'O celular avisa quando faltar este tempo para acabar.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final int option in DailyLimitWarnings.options)
                FilterChip(
                  label: Text(formatMinutes(option)),
                  selected: selected.contains(option),
                  onSelected: limit.canEnableWarning(option)
                      ? (bool value) {
                          bloc.add(DailyLimitWarningToggled(minutes: option, enabled: value));
                        }
                      : null,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(helper, style: context.text.bodySmall),
          ),
          if (tooEarly) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppBanner(
              tone: Tone.warning,
              message:
                  'Há aviso maior que o tempo de algum dia (${formatMinutes(smallestLimit)}). '
                  'Nesse dia ele aparece logo no começo do uso.',
            ),
          ],
        ],
      ),
    );
  }
}
