import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/texts/describe_days.dart';
import '../../../device_policy/presentation/widgets/rule_editor_scaffold.dart';
import '../../domain/entities/block_period_draft.dart';
import '../../domain/entities/block_period_suggestion.dart';
import '../../domain/entities/schedule_rules.dart';
import '../../domain/services/block_period_editing.dart';
import '../bloc/schedule/schedule_bloc.dart';
import '../texts/schedule_texts.dart';

const List<HelpTopic> _periodsHelp = <HelpTopic>[
  HelpTopic(
    title: 'O que acontece durante um período?',
    body:
        'O celular fica em pausa: só as exceções, as ligações e as funções essenciais '
        'funcionam. A criança vê o motivo e quando o celular volta.',
  ),
  HelpTopic(
    title: 'E se o período passar da meia-noite?',
    body:
        'Marque o dia em que ele começa. Uma hora de dormir das 21:00 às 07:00 marcada na sexta '
        'termina no sábado de manhã.',
  ),
  HelpTopic(
    title: 'Toda semana ou uma vez?',
    body:
        'Toda semana repete nos dias escolhidos, como a hora de dormir e a escola. Uma vez vale '
        'só entre a data e a hora de início e de fim, como uma prova ou uma viagem.',
  ),
];

/// Atalhos de dias no formulario de periodo.
const List<({String label, Set<int> days})> _dayShortcuts = <({String label, Set<int> days})>[
  (label: 'Todos os dias', days: <int>{1, 2, 3, 4, 5, 6, 7}),
  (label: 'Seg a sex', days: <int>{1, 2, 3, 4, 5}),
  (label: 'Sáb e dom', days: <int>{6, 7}),
];

IconData _suggestionIcon(BlockPeriodSuggestion suggestion) {
  return switch (suggestion) {
    BlockPeriodSuggestion.bedtime => AppIcons.bedtime,
    BlockPeriodSuggestion.school => AppIcons.categoryEducation,
  };
}

/// Periodos de bloqueio: recorrentes por dia da semana ou pontuais com data e hora.
///
/// Espera um [ScheduleBloc] acima na arvore, ja iniciado para [device].
class BlockPeriodsPage extends StatelessWidget {
  const BlockPeriodsPage({required this.device, super.key});

  final ChildDevice device;

  Future<void> _edit(BuildContext context, BlockPeriod? current) async {
    final ScheduleBloc bloc = context.read<ScheduleBloc>();
    final _PeriodEdit? result = await showAppSheet<_PeriodEdit>(
      context,
      title: current == null ? 'Novo período' : 'Editar período',
      builder: (BuildContext context) => _PeriodForm(initial: current),
    );
    if (result == null) {
      return;
    }
    final BlockPeriodDraft? draft = result.draft;
    if (draft != null) {
      bloc.add(BlockPeriodSaved(draft));
    } else if (current != null) {
      bloc.add(BlockPeriodDeleted(current.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScheduleBloc bloc = context.read<ScheduleBloc>();
    final String name = device.displayName;
    return RuleEditorScaffold<ScheduleBloc, ScheduleRules>(
      title: 'Períodos de bloqueio',
      description: 'Momentos em que o celular de $name fica em pausa, como a hora de dormir.',
      device: device,
      helpTopics: _periodsHelp,
      onSave: () => bloc.add(const ScheduleSaveRequested()),
      onDiscard: () => bloc.add(const ScheduleDiscardRequested()),
      onRetry: () => bloc.add(ScheduleStarted(device.id)),
      onRestoreRejected: () => bloc.add(const ScheduleRejectedChangesRestored()),
      children: (BuildContext context, ScheduleRules rules) {
        final List<BlockPeriod> periods = rules.blockPeriods;
        final int now = context.read<Clock>().nowMs();
        final bool canAdd = BlockPeriodEditing.canAdd(periods);
        return <Widget>[
          if (periods.isEmpty)
            AppSection(
              title: 'Nenhum período criado',
              subtitle: 'Comece por um modelo ou crie o seu. Dá para ajustar tudo depois.',
              child: AppListGroup(
                children: <Widget>[
                  for (final BlockPeriodSuggestion suggestion in BlockPeriodSuggestion.values)
                    AppListRow(
                      leading: AppIconTile(icon: _suggestionIcon(suggestion), tone: Tone.rest),
                      title: suggestion.label,
                      subtitle: describeBlockPeriod(suggestion.toPeriod('modelo')),
                      trailing: Icon(AppIcons.addCircle, color: context.colors.primary),
                      onTap: () => bloc.add(BlockPeriodSuggestionAdded(suggestion)),
                    ),
                ],
              ),
            )
          else
            AppSection(
              title: 'Períodos de $name',
              subtitle:
                  'Durante um período, só as exceções funcionam. Chamadas de emergência '
                  'nunca são bloqueadas.',
              child: AppListGroup(
                children: <Widget>[
                  for (final BlockPeriod period in periods)
                    _PeriodRow(
                      period: period,
                      ended: BlockPeriodEditing.hasEnded(period, now),
                      onTap: () => _edit(context, period),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.secondary(
            label: 'Novo período',
            icon: AppIcons.add,
            expand: true,
            onPressed: canAdd ? () => _edit(context, null) : null,
          ),
          if (!canAdd) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Você chegou ao máximo de ${BlockPeriodEditing.maxPeriods} períodos. Exclua um '
              'para criar outro.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          ],
        ];
      },
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.period, required this.ended, required this.onTap});

  final BlockPeriod period;
  final bool ended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool once = period.kind == BlockPeriodKind.once;
    final bool active = period.enabled && !ended;
    final Widget? badge = ended
        ? const StatusBadge(label: 'Encerrado', icon: AppIcons.history)
        : !period.enabled
        ? const StatusBadge(label: 'Desativado', icon: AppIcons.pause)
        : null;
    return AppListRow(
      key: ValueKey<String>('period-${period.id}'),
      leading: AppIconTile(
        icon: once ? AppIcons.calendar : AppIcons.bedtime,
        tone: active ? Tone.rest : Tone.neutral,
      ),
      title: period.label.isEmpty ? 'Sem nome' : period.label,
      subtitle: describeBlockPeriod(period),
      below: badge == null
          ? null
          : Align(alignment: AlignmentDirectional.centerStart, child: badge),
      onTap: onTap,
    );
  }
}

/// Resultado da folha de edicao: o periodo preenchido, ou nulo em [draft] para excluir.
class _PeriodEdit {
  const _PeriodEdit(this.draft);

  final BlockPeriodDraft? draft;
}

class _PeriodForm extends StatefulWidget {
  const _PeriodForm({this.initial});

  final BlockPeriod? initial;

  @override
  State<_PeriodForm> createState() => _PeriodFormState();
}

class _PeriodFormState extends State<_PeriodForm> {
  late final Clock _clock = context.read<Clock>();
  late final TextEditingController _label = TextEditingController(
    text: widget.initial?.label ?? '',
  );
  late BlockPeriodKind _kind = widget.initial?.kind ?? BlockPeriodKind.weekly;
  late Set<int> _days = <int>{
    ...widget.initial?.days ?? const <int>[1, 2, 3, 4, 5, 6, 7],
  };
  late LocalTime _start = widget.initial?.start ?? const LocalTime(21, 0);
  late LocalTime _end = widget.initial?.end ?? const LocalTime(7, 0);
  late DateTime _startAt = _initialInstant(widget.initial?.startAt, 0);
  late DateTime _endAt = _initialInstant(widget.initial?.endAt, 2);
  late bool _enabled = widget.initial?.enabled ?? true;
  String? _error;

  DateTime _initialInstant(int? ms, int hoursAhead) {
    if (ms != null) {
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return BlockPeriodEditing.suggestedInstant(_clock.now(), hoursAhead: hoursAhead);
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _useSuggestion(BlockPeriodSuggestion suggestion) {
    setState(() {
      _label.text = suggestion.label;
      _kind = BlockPeriodKind.weekly;
      _days = <int>{...suggestion.days};
      _start = suggestion.start;
      _end = suggestion.end;
      _error = null;
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final LocalTime current = start ? _start : _end;
    final ({int hour, int minute})? picked = await pickTimeOfDay(
      context,
      hour: current.hour,
      minute: current.minute,
      helpText: start ? 'Início do bloqueio' : 'Fim do bloqueio',
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

  Future<void> _pickInstant({required bool start}) async {
    final DateTime current = start ? _startAt : _endAt;
    final DateTime now = _clock.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) {
      return;
    }
    final ({int hour, int minute})? time = await pickTimeOfDay(
      context,
      hour: current.hour,
      minute: current.minute,
    );
    if (time == null) {
      return;
    }
    setState(() {
      final DateTime value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (start) {
        _startAt = value;
      } else {
        _endAt = value;
      }
      _error = null;
    });
  }

  void _save() {
    final BlockPeriodDraft draft = BlockPeriodDraft(
      id: widget.initial?.id,
      label: _label.text,
      kind: _kind,
      days: _days,
      start: _start,
      end: _end,
      startAt: _startAt,
      endAt: _endAt,
      enabled: _enabled,
    );
    final String? problem = draft.problemAt(_clock.now());
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(_PeriodEdit(draft));
  }

  Future<void> _delete() async {
    final String name = _label.text.trim().isEmpty ? 'sem nome' : _label.text.trim();
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Excluir o período "$name"?',
      message: 'Ele deixa de bloquear o celular quando você salvar as regras.',
      consequence: 'Depois de salvar, não dá para desfazer.',
      confirmLabel: 'Excluir período',
      destructive: true,
      icon: AppIcons.delete,
    );
    if (confirmed && mounted) {
      Navigator.of(context).pop(const _PeriodEdit(null));
    }
  }

  String _instant(DateTime value) => '${formatShortDate(value)} às ${formatClock(value)}';

  @override
  Widget build(BuildContext context) {
    final bool weekly = _kind == BlockPeriodKind.weekly;
    final bool crosses = _start.compareTo(_end) > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.initial == null) ...<Widget>[
          Text('Começar de um modelo', style: context.text.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          AppChoiceChips<BlockPeriodSuggestion>(
            choices: <AppChoice<BlockPeriodSuggestion>>[
              for (final BlockPeriodSuggestion suggestion in BlockPeriodSuggestion.values)
                AppChoice<BlockPeriodSuggestion>(
                  value: suggestion,
                  label: suggestion.label,
                  icon: _suggestionIcon(suggestion),
                ),
            ],
            selected: null,
            onSelected: _useSuggestion,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        AppTextField(
          controller: _label,
          label: 'Nome',
          hint: 'Hora de dormir',
          isRequired: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSegmentedControl<BlockPeriodKind>(
          segments: const <AppChoice<BlockPeriodKind>>[
            AppChoice<BlockPeriodKind>(
              value: BlockPeriodKind.weekly,
              label: 'Toda semana',
              icon: AppIcons.repeat,
            ),
            AppChoice<BlockPeriodKind>(
              value: BlockPeriodKind.once,
              label: 'Uma vez',
              icon: AppIcons.calendar,
            ),
          ],
          selected: _kind,
          onChanged: (BlockPeriodKind value) => setState(() {
            _kind = value;
            _error = null;
          }),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (weekly) ...<Widget>[
          Semantics(
            header: true,
            child: Text('Dias em que o bloqueio começa', style: context.text.titleSmall),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Se passar da meia-noite, marque o dia em que ele começa.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (int day = 1; day <= 7; day++)
                FilterChip(
                  label: Text(weekdayShort(day)),
                  tooltip: weekdayLong(day),
                  selected: _days.contains(day),
                  onSelected: (bool selected) {
                    setState(() {
                      _days = <int>{..._days};
                      if (selected) {
                        _days.add(day);
                      } else {
                        _days.remove(day);
                      }
                      _error = null;
                    });
                  },
                ),
            ],
          ),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final ({String label, Set<int> days}) shortcut in _dayShortcuts)
                AppButton.tertiary(
                  label: shortcut.label,
                  size: AppButtonSize.compact,
                  onPressed: () => setState(() {
                    _days = <int>{...shortcut.days};
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppListGroup(
            dividerIndent: AppSpacing.lg,
            footer: crosses
                ? 'Termina às $_end do dia seguinte. ${capitalizeFirst(describeDays(_days))}.'
                : '${capitalizeFirst(describeDays(_days))}.',
            children: <Widget>[
              AppListRow(
                title: 'Começa às',
                titleStyle: context.text.bodyLarge,
                trailing: Text('$_start', style: context.textStyles.metricSmall),
                showChevron: true,
                onTap: () => _pickTime(start: true),
              ),
              AppListRow(
                title: 'Termina às',
                titleStyle: context.text.bodyLarge,
                trailing: Text('$_end', style: context.textStyles.metricSmall),
                showChevron: true,
                onTap: () => _pickTime(start: false),
              ),
            ],
          ),
        ] else
          AppListGroup(
            dividerIndent: AppSpacing.lg,
            children: <Widget>[
              AppListRow(
                title: 'Começa',
                titleStyle: context.text.bodyLarge,
                trailing: Text(_instant(_startAt), style: context.textStyles.metricSmall),
                showChevron: true,
                onTap: () => _pickInstant(start: true),
              ),
              AppListRow(
                title: 'Termina',
                titleStyle: context.text.bodyLarge,
                trailing: Text(_instant(_endAt), style: context.textStyles.metricSmall),
                showChevron: true,
                onTap: () => _pickInstant(start: false),
              ),
            ],
          ),
        if (widget.initial != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppListGroup(
            children: <Widget>[
              AppSwitchRow(
                icon: AppIcons.bedtime,
                tone: Tone.rest,
                title: 'Período ativo',
                subtitle: _enabled
                    ? 'Bloqueia o celular nos horários acima.'
                    : 'Fica guardado, mas não bloqueia.',
                value: _enabled,
                onChanged: (bool value) => setState(() => _enabled = value),
              ),
            ],
          ),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          AppBanner(tone: Tone.danger, liveRegion: true, message: _error!),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton.primary(label: 'Concluir', expand: true, onPressed: _save),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'O período vai para o aparelho quando você salvar as regras.',
          textAlign: TextAlign.center,
          style: context.text.bodySmall,
        ),
        if (widget.initial != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          AppButton.tertiary(
            label: 'Excluir período',
            icon: AppIcons.delete,
            expand: true,
            onPressed: _delete,
          ),
        ],
      ],
    );
  }
}
