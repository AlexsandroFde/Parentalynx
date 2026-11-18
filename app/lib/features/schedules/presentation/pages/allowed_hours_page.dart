import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/editing/policy_section_state.dart';
import '../../../device_policy/presentation/texts/describe_days.dart';
import '../../../device_policy/presentation/widgets/rule_editor_scaffold.dart';
import '../../domain/entities/day_window.dart';
import '../../domain/entities/schedule_rules.dart';
import '../../domain/services/allowed_hours_editing.dart';
import '../bloc/schedule/schedule_bloc.dart';

const List<HelpTopic> _hoursHelp = <HelpTopic>[
  HelpTopic(
    title: 'Como funcionam os horários permitidos?',
    body:
        'O celular só pode ser usado dentro dos horários liberados de cada dia. Fora deles, só '
        'as exceções, as ligações e as funções essenciais funcionam. Um dia sem nenhum horário '
        'fica bloqueado do começo ao fim.',
  ),
  HelpTopic(
    title: 'E o limite diário e os períodos de bloqueio?',
    body:
        'Valem juntos. Dentro do horário liberado o tempo continua contando no limite diário, e '
        'um período de bloqueio (como a hora de dormir) bloqueia mesmo dentro do horário.',
  ),
  HelpTopic(
    title: 'Em que fuso valem os horários?',
    body: 'No fuso que o aparelho da criança informou quando foi vinculado.',
  ),
];

/// Atalhos de copia dos horarios de um dia para outros dias.
const List<({String label, List<int> days})> _copyTargets = <({String label, List<int> days})>[
  (label: 'Seg a sex', days: <int>[1, 2, 3, 4, 5]),
  (label: 'Sáb e dom', days: <int>[6, 7]),
  (label: 'Todos os dias', days: <int>[1, 2, 3, 4, 5, 6, 7]),
];

String _dayName(int day) => capitalizeFirst(weekdayLong(day));

String _describeWindows(List<DayWindow> windows) {
  if (windows.isEmpty) {
    return 'Bloqueado o dia inteiro';
  }
  final List<String> parts = windows.map((DayWindow w) => '$w').toList();
  return parts.length == 1
      ? parts.single
      : '${parts.sublist(0, parts.length - 1).join(', ')} e ${parts.last}';
}

/// Horarios permitidos por dia da semana. Dia sem janela fica bloqueado o dia inteiro.
///
/// A semana aparece de uma vez; cada dia abre uma folha para liberar, remover e copiar
/// horarios.
///
/// Espera um [ScheduleBloc] acima na arvore, ja iniciado para [device].
class AllowedHoursPage extends StatelessWidget {
  const AllowedHoursPage({required this.device, super.key});

  final ChildDevice device;

  Future<void> _openDay(BuildContext context, int day) {
    final ScheduleBloc bloc = context.read<ScheduleBloc>();
    return showAppSheet<void>(
      context,
      title: _dayName(day),
      subtitle: 'Quando ${device.displayName} pode usar o celular.',
      builder: (BuildContext context) {
        return BlocProvider<ScheduleBloc>.value(
          value: bloc,
          child: _DaySheet(day: day),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScheduleBloc bloc = context.read<ScheduleBloc>();
    return RuleEditorScaffold<ScheduleBloc, ScheduleRules>(
      title: 'Horários permitidos',
      description: 'Em que horários ${device.displayName} pode usar o celular.',
      device: device,
      helpTopics: _hoursHelp,
      onSave: () => bloc.add(const ScheduleSaveRequested()),
      onDiscard: () => bloc.add(const ScheduleDiscardRequested()),
      onRetry: () => bloc.add(ScheduleStarted(device.id)),
      onRestoreRejected: () => bloc.add(const ScheduleRejectedChangesRestored()),
      children: (BuildContext context, ScheduleRules rules) {
        final AllowedHours hours = rules.allowedHours;
        final WeekWindows byDay = expandAllowedHours(hours);
        final List<int> blocked = blockedDays(byDay);
        return <Widget>[
          AppListGroup(
            children: <Widget>[
              AppSwitchRow(
                icon: AppIcons.allowedHours,
                title: 'Limitar os horários de uso',
                subtitle: 'Fora dos horários liberados, só as exceções funcionam.',
                value: hours.enabled,
                onChanged: (bool value) => bloc.add(AllowedHoursToggled(value)),
              ),
            ],
          ),
          if (!hours.enabled) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            const AppBanner(
              tone: Tone.neutral,
              message:
                  'Sem restrição de horário, o celular pode ser usado a qualquer hora, dentro do '
                  'limite diário e fora dos períodos de bloqueio.',
            ),
          ] else ...<Widget>[
            const SectionGap(),
            if (blocked.isNotEmpty) ...<Widget>[
              AppBanner(
                tone: Tone.warning,
                title: 'Dias sem nenhum horário liberado',
                message:
                    '${capitalizeFirst(describeDays(blocked))}: o celular fica bloqueado o dia '
                    'inteiro. Toque no dia para liberar um horário.',
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppSection(
              title: 'Horários de cada dia',
              subtitle: 'Toque em um dia para mudar.',
              child: AppListGroup(
                children: <Widget>[
                  for (int day = 1; day <= 7; day++)
                    AppListRow(
                      key: ValueKey<String>('day-$day'),
                      leading: AppIconTile(
                        icon: (byDay[day] ?? const <DayWindow>[]).isEmpty
                            ? AppIcons.blocked
                            : AppIcons.allowedHours,
                        tone: (byDay[day] ?? const <DayWindow>[]).isEmpty
                            ? Tone.warning
                            : Tone.info,
                      ),
                      title: _dayName(day),
                      subtitle: _describeWindows(byDay[day] ?? const <DayWindow>[]),
                      onTap: () => _openDay(context, day),
                    ),
                ],
              ),
            ),
          ],
        ];
      },
    );
  }
}

/// Folha de um dia: horarios liberados, inclusao com conferencia e copia para outros dias.
class _DaySheet extends StatefulWidget {
  const _DaySheet({required this.day});

  final int day;

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  LocalTime? _start;
  LocalTime? _end;
  bool _untilEndOfDay = false;
  String? _error;

  List<DayWindow> _windows(ScheduleState state) {
    if (state is! PolicySectionEditing<ScheduleRules>) {
      return const <DayWindow>[];
    }
    return expandAllowedHours(state.draft.allowedHours)[widget.day] ?? const <DayWindow>[];
  }

  /// Sugestao de horario novo: depois do ultimo horario do dia, ou 07:00 as 21:00.
  ({LocalTime start, LocalTime end}) _suggestion(List<DayWindow> windows) {
    if (windows.isEmpty) {
      return (start: const LocalTime(7, 0), end: const LocalTime(21, 0));
    }
    final int after = windows.last.end.minutesOfDay;
    if (after >= 23 * 60) {
      return (start: const LocalTime(7, 0), end: const LocalTime(8, 0));
    }
    return (
      start: LocalTime.fromMinutes(after),
      end: LocalTime.fromMinutes((after + 60).clamp(0, 24 * 60)),
    );
  }

  Future<void> _pick({required bool start, required LocalTime current}) async {
    final ({int hour, int minute})? picked = await pickTimeOfDay(
      context,
      hour: current.hour,
      minute: current.minute,
      helpText: start ? 'Início do horário liberado' : 'Fim do horário liberado',
    );
    if (picked != null) {
      setState(() {
        final LocalTime value = LocalTime(picked.hour, picked.minute);
        if (start) {
          _start = value;
        } else {
          _end = value;
        }
        _error = null;
      });
    }
  }

  void _add(List<DayWindow> windows, LocalTime start, LocalTime end) {
    final DayWindow window = DayWindow(start, _untilEndOfDay ? LocalTime.endOfDay : end);
    final String? problem = validateNewDayWindow(windows, window);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    context.read<ScheduleBloc>().add(AllowedHoursWindowAdded(weekday: widget.day, window: window));
    setState(() {
      _start = null;
      _end = null;
      _untilEndOfDay = false;
      _error = null;
    });
  }

  Future<void> _copy(List<DayWindow> windows, List<int> days) async {
    final ScheduleBloc bloc = context.read<ScheduleBloc>();
    final List<int> targets = days.where((int d) => d != widget.day).toList();
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Copiar para ${describeDays(days)}?',
      message:
          'Os horários de ${describeDays(targets)} passam a ser: '
          '${_describeWindows(windows).toLowerCase()}.',
      consequence: 'Os horários atuais desses dias são substituídos.',
      confirmLabel: 'Copiar horários',
      icon: AppIcons.copyAll,
    );
    if (confirmed && mounted) {
      bloc.add(AllowedHoursDayCopied(weekday: widget.day, to: targets));
      showAppSnackBar(context, 'Horários copiados para ${describeDays(targets)}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScheduleBloc, ScheduleState>(
      builder: (BuildContext context, ScheduleState state) {
        final List<DayWindow> windows = _windows(state);
        final ({LocalTime start, LocalTime end}) suggested = _suggestion(windows);
        final LocalTime start = _start ?? suggested.start;
        final LocalTime end = _end ?? suggested.end;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (windows.isEmpty)
              const AppBanner(
                tone: Tone.warning,
                message: 'Sem horário liberado, o celular fica bloqueado o dia inteiro.',
              )
            else
              AppListGroup(
                dividerIndent: AppSpacing.lg,
                children: <Widget>[
                  for (final DayWindow window in windows)
                    AppListRow(
                      title: '$window',
                      titleStyle: context.text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                      trailing: AppIconButton(
                        icon: AppIcons.delete,
                        tooltip: 'Remover $window',
                        onPressed: () {
                          context.read<ScheduleBloc>().add(
                            AllowedHoursWindowRemoved(weekday: widget.day, window: window),
                          );
                        },
                      ),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.xl),
            Semantics(
              header: true,
              child: Text('Liberar outro horário', style: context.text.titleSmall),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppListGroup(
              dividerIndent: AppSpacing.lg,
              children: <Widget>[
                AppListRow(
                  title: 'Começa às',
                  titleStyle: context.text.bodyLarge,
                  trailing: Text('$start', style: context.textStyles.metricSmall),
                  showChevron: true,
                  onTap: () => _pick(start: true, current: start),
                ),
                AppListRow(
                  title: 'Termina às',
                  titleStyle: context.text.bodyLarge,
                  enabled: !_untilEndOfDay,
                  trailing: Text(
                    _untilEndOfDay ? '24:00' : '$end',
                    style: context.textStyles.metricSmall,
                  ),
                  showChevron: true,
                  onTap: _untilEndOfDay ? null : () => _pick(start: false, current: end),
                ),
                AppSwitchRow(
                  title: 'Até o fim do dia',
                  value: _untilEndOfDay,
                  onChanged: (bool value) => setState(() {
                    _untilEndOfDay = value;
                    _error = null;
                  }),
                ),
              ],
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              AppBanner(tone: Tone.danger, liveRegion: true, message: _error!),
            ],
            const SizedBox(height: AppSpacing.md),
            AppButton.secondary(
              key: ValueKey<String>('add-window-${widget.day}'),
              label: 'Liberar este horário',
              icon: AppIcons.add,
              expand: true,
              onPressed: () => _add(windows, start, end),
            ),
            const SizedBox(height: AppSpacing.xl),
            Semantics(
              header: true,
              child: Text('Copiar os horários deste dia para', style: context.text.titleSmall),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final ({String label, List<int> days}) target in _copyTargets)
                  if (target.days.any((int d) => d != widget.day))
                    AppButton.tertiary(
                      label: target.label,
                      icon: AppIcons.copyAll,
                      size: AppButtonSize.compact,
                      onPressed: () => _copy(windows, target.days),
                    ),
              ],
            ),
          ],
        );
      },
    );
  }
}
