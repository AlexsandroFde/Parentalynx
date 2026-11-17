import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/domain/policy.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../domain/ids.dart';
import '../domain/policy_summaries.dart';
import 'widgets/duration_picker.dart';
import 'widgets/rule_scaffold.dart';

const int _maxPeriods = 50;

/// Periodos de bloqueio: recorrentes por dia da semana ou pontuais com data e hora.
class BlockPeriodsPage extends StatelessWidget {
  const BlockPeriodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RuleEditorScaffold(
      title: 'Períodos de bloqueio',
      children: (BuildContext context, RuleEditing editing) {
        final List<BlockPeriod> periods = editing.draft.blockPeriods;

        void setPeriods(List<BlockPeriod> next) {
          editing.update((Policy policy) => policy.copyWith(blockPeriods: next));
        }

        Future<void> edit(BlockPeriod? current) async {
          final _PeriodEdit? result = await showModalBottomSheet<_PeriodEdit>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (BuildContext context) => _PeriodSheet(initial: current),
          );
          if (result == null) {
            return;
          }
          final BlockPeriod? saved = result.period;
          if (saved == null) {
            setPeriods(periods.where((BlockPeriod p) => p.id != current?.id).toList());
          } else if (current == null) {
            setPeriods(<BlockPeriod>[...periods, saved]);
          } else {
            setPeriods(<BlockPeriod>[
              for (final BlockPeriod p in periods)
                if (p.id == current.id) saved else p,
            ]);
          }
        }

        void addSuggestion(String label, List<int> days, LocalTime start, LocalTime end) {
          setPeriods(<BlockPeriod>[
            ...periods,
            BlockPeriod.weekly(id: newUuid(), label: label, days: days, start: start, end: end),
          ]);
        }

        return <Widget>[
          const NoticeBanner(
            message:
                'Durante um período de bloqueio só os apps marcados como exceção funcionam. '
                'Chamadas de emergência nunca são bloqueadas.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (periods.isEmpty)
            SectionCard(
              title: 'Nenhum período criado',
              subtitle: 'Comece por uma sugestão ou crie o seu.',
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  ActionChip(
                    avatar: const Icon(Icons.bedtime_outlined, size: 18),
                    label: const Text('Hora de dormir, 21:00 às 07:00'),
                    onPressed: () => addSuggestion(
                      'Hora de dormir',
                      const <int>[1, 2, 3, 4, 5, 6, 7],
                      const LocalTime(21, 0),
                      const LocalTime(7, 0),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.school_outlined, size: 18),
                    label: const Text('Escola, seg a sex, 07:00 às 12:00'),
                    onPressed: () => addSuggestion(
                      'Escola',
                      const <int>[1, 2, 3, 4, 5],
                      const LocalTime(7, 0),
                      const LocalTime(12, 0),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final BlockPeriod period in periods) ...<Widget>[
              _PeriodCard(
                period: period,
                onTap: () => edit(period),
                onToggle: (bool value) => setPeriods(<BlockPeriod>[
                  for (final BlockPeriod p in periods)
                    if (p.id == period.id) p.withEnabled(value) else p,
                ]),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: periods.length >= _maxPeriods ? null : () => edit(null),
            icon: const Icon(Icons.add),
            label: const Text('Novo período'),
          ),
        ];
      },
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.period, required this.onTap, required this.onToggle});

  final BlockPeriod period;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool once = period.kind == BlockPeriodKind.once;
    final bool ended = once && (period.endAt ?? 0) < DateTime.now().millisecondsSinceEpoch;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: <Widget>[
              Icon(
                once ? Icons.event_outlined : Icons.event_repeat_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      period.label.isEmpty ? 'Sem nome' : period.label,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      describeBlockPeriod(period),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (ended)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: StatusPill(label: 'Encerrado', icon: Icons.history),
                      ),
                  ],
                ),
              ),
              Semantics(
                label: 'Ativar ${period.label}',
                child: Switch(value: period.enabled, onChanged: onToggle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resultado da folha de edicao: o periodo gravado, ou nulo em `period` para excluir.
class _PeriodEdit {
  const _PeriodEdit(this.period);

  final BlockPeriod? period;
}

class _PeriodSheet extends StatefulWidget {
  const _PeriodSheet({this.initial});

  final BlockPeriod? initial;

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
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
  String? _error;

  static DateTime _initialInstant(int? ms, int hoursAhead) {
    if (ms != null) {
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour + 1 + hoursAhead);
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
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
      });
    }
  }

  Future<void> _pickInstant({required bool start}) async {
    final DateTime current = start ? _startAt : _endAt;
    final DateTime now = DateTime.now();
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
    });
  }

  void _save() {
    final String label = _label.text.trim();
    final String id = widget.initial?.id ?? newUuid();
    final bool enabled = widget.initial?.enabled ?? true;
    if (label.isEmpty) {
      setState(() => _error = 'Dê um nome ao período, por exemplo "Hora de dormir".');
      return;
    }
    if (_kind == BlockPeriodKind.weekly) {
      if (_days.isEmpty) {
        setState(() => _error = 'Escolha pelo menos um dia da semana.');
        return;
      }
      if (_start == _end) {
        setState(() => _error = 'O início e o fim não podem ser iguais.');
        return;
      }
      Navigator.of(context).pop(
        _PeriodEdit(
          BlockPeriod.weekly(
            id: id,
            label: label,
            days: _days.toList()..sort(),
            start: _start,
            end: _end,
            enabled: enabled,
          ),
        ),
      );
      return;
    }
    if (!_endAt.isAfter(_startAt)) {
      setState(() => _error = 'O fim precisa ser depois do início.');
      return;
    }
    Navigator.of(context).pop(
      _PeriodEdit(
        BlockPeriod.once(
          id: id,
          label: label,
          startAt: _startAt.millisecondsSinceEpoch,
          endAt: _endAt.millisecondsSinceEpoch,
          enabled: enabled,
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Excluir período?',
      message: 'O período "${_label.text.trim()}" deixa de valer quando você salvar as regras.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (confirmed && mounted) {
      Navigator.of(context).pop(const _PeriodEdit(null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool weekly = _kind == BlockPeriodKind.weekly;
    final bool crosses = _start.compareTo(_end) > 0;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.initial == null ? 'Novo período' : 'Editar período',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _label,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nome', hintText: 'Hora de dormir'),
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<BlockPeriodKind>(
            segments: const <ButtonSegment<BlockPeriodKind>>[
              ButtonSegment<BlockPeriodKind>(
                value: BlockPeriodKind.weekly,
                label: Text('Toda semana'),
                icon: Icon(Icons.event_repeat_outlined),
              ),
              ButtonSegment<BlockPeriodKind>(
                value: BlockPeriodKind.once,
                label: Text('Uma vez'),
                icon: Icon(Icons.event_outlined),
              ),
            ],
            selected: <BlockPeriodKind>{_kind},
            onSelectionChanged: (Set<BlockPeriodKind> value) {
              setState(() => _kind = value.first);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          if (weekly) ...<Widget>[
            Text('Dias em que o bloqueio começa', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              children: <Widget>[
                for (int day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(weekdayShort(day)),
                    selected: _days.contains(day),
                    onSelected: (bool selected) {
                      setState(() {
                        _days = <int>{..._days};
                        if (selected) {
                          _days.add(day);
                        } else {
                          _days.remove(day);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ValueTile(
                    label: 'Início',
                    value: '$_start',
                    onTap: () => _pickTime(start: true),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _ValueTile(
                    label: 'Fim',
                    value: crosses ? '$_end (dia seguinte)' : '$_end',
                    onTap: () => _pickTime(start: false),
                  ),
                ),
              ],
            ),
          ] else ...<Widget>[
            _ValueTile(
              label: 'Início',
              value: '${formatShortDate(_startAt)} às ${formatClock(_startAt)}',
              onTap: () => _pickInstant(start: true),
            ),
            const SizedBox(height: AppSpacing.md),
            _ValueTile(
              label: 'Fim',
              value: '${formatShortDate(_endAt)} às ${formatClock(_endAt)}',
              onTap: () => _pickInstant(start: false),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            NoticeBanner(tone: Tone.danger, message: _error!),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(onPressed: _save, child: const Text('Concluir')),
          if (widget.initial != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Excluir período'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Campo de leitura que abre um seletor ao toque.
class _ValueTile extends StatelessWidget {
  const _ValueTile({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.schedule, size: 20),
        ),
        child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
