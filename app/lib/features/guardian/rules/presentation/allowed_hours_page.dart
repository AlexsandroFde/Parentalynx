import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/domain/policy.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../domain/allowed_hours_editing.dart';
import '../domain/policy_summaries.dart';
import 'widgets/duration_picker.dart';
import 'widgets/rule_scaffold.dart';

/// Horarios permitidos por dia da semana. Dia sem janela fica bloqueado o dia inteiro.
class AllowedHoursPage extends StatelessWidget {
  const AllowedHoursPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RuleEditorScaffold(
      title: 'Horários permitidos',
      children: (BuildContext context, RuleEditing editing) {
        final AllowedHours hours = editing.draft.allowedHours;
        final WeekWindows byDay = expandAllowedHours(hours);
        final List<int> blocked = blockedDays(byDay);

        void setWeek(WeekWindows week) {
          editing.update(
            (Policy p) => p.copyWith(
              allowedHours: p.allowedHours.copyWith(windows: compactAllowedHours(week)),
            ),
          );
        }

        void toggle(bool value) {
          editing.update((Policy p) {
            // Ao ligar sem nenhuma janela, comeca com um horario comum em todos os dias,
            // para nao bloquear a semana inteira sem querer.
            final List<TimeWindow> windows = value && p.allowedHours.windows.isEmpty
                ? const <TimeWindow>[
                    TimeWindow(
                      days: <int>[1, 2, 3, 4, 5, 6, 7],
                      start: LocalTime(7, 0),
                      end: LocalTime(21, 0),
                    ),
                  ]
                : p.allowedHours.windows;
            return p.copyWith(
              allowedHours: AllowedHours(enabled: value, windows: windows),
            );
          });
        }

        Future<void> add(int day) async {
          final DayWindow? window = await showDialog<DayWindow>(
            context: context,
            builder: (BuildContext context) => _WindowDialog(day: day),
          );
          if (window != null) {
            setWeek(addDayWindow(byDay, day, window));
          }
        }

        return <Widget>[
          SwitchCard(
            icon: Icons.schedule,
            title: 'Restringir os horários de uso',
            subtitle: 'Fora dos horários liberados, só as exceções funcionam.',
            value: hours.enabled,
            onChanged: toggle,
          ),
          const SizedBox(height: AppSpacing.md),
          if (!hours.enabled)
            const NoticeBanner(
              message: 'Sem restrição de horário, o aparelho pode ser usado a qualquer hora.',
            )
          else ...<Widget>[
            if (blocked.isNotEmpty) ...<Widget>[
              NoticeBanner(
                tone: Tone.warning,
                title: 'Dias bloqueados o dia inteiro',
                message:
                    'Dia sem nenhum horário liberado fica bloqueado do início ao fim: '
                    '${describeDays(blocked)}.',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            for (int day = 1; day <= 7; day++) ...<Widget>[
              _DayCard(
                day: day,
                windows: byDay[day] ?? const <DayWindow>[],
                onAdd: () => add(day),
                onRemove: (DayWindow window) => setWeek(removeDayWindow(byDay, day, window)),
                onCopyToAll: () =>
                    setWeek(copyDayWindows(byDay, from: day, to: const <int>[1, 2, 3, 4, 5, 6, 7])),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ];
      },
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.windows,
    required this.onAdd,
    required this.onRemove,
    required this.onCopyToAll,
  });

  final int day;
  final List<DayWindow> windows;
  final VoidCallback onAdd;
  final ValueChanged<DayWindow> onRemove;
  final VoidCallback onCopyToAll;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = weekdayLong(day);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${name[0].toUpperCase()}${name.substring(1)}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar os horários de $name para todos os dias',
                  icon: const Icon(Icons.copy_all_outlined),
                  onPressed: onCopyToAll,
                ),
                IconButton(
                  key: ValueKey<String>('add-window-$day'),
                  tooltip: 'Adicionar horário em $name',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onAdd,
                ),
              ],
            ),
            if (windows.isEmpty)
              const StatusPill(
                label: 'Bloqueado o dia inteiro',
                tone: Tone.danger,
                icon: Icons.block,
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final DayWindow window in windows)
                    InputChip(
                      label: Text('$window'),
                      deleteButtonTooltipMessage: 'Remover horário',
                      onDeleted: () => onRemove(window),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _WindowDialog extends StatefulWidget {
  const _WindowDialog({required this.day});

  final int day;

  @override
  State<_WindowDialog> createState() => _WindowDialogState();
}

class _WindowDialogState extends State<_WindowDialog> {
  LocalTime _start = const LocalTime(7, 0);
  LocalTime _end = const LocalTime(21, 0);
  bool _untilEndOfDay = false;
  String? _error;

  Future<void> _pick({required bool start}) async {
    final LocalTime current = start ? _start : _end;
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

  void _confirm() {
    final LocalTime end = _untilEndOfDay ? LocalTime.endOfDay : _end;
    final String? error = validateDayWindow(_start, end);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(DayWindow(_start, end));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Horário liberado, ${weekdayLong(widget.day)}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Início'),
            trailing: Text('$_start', style: Theme.of(context).textTheme.titleMedium),
            onTap: () => _pick(start: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: !_untilEndOfDay,
            title: const Text('Fim'),
            trailing: Text(
              _untilEndOfDay ? '24:00' : '$_end',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _pick(start: false),
          ),
          SwitchRow(
            title: 'Até o fim do dia',
            value: _untilEndOfDay,
            onChanged: (bool value) => setState(() {
              _untilEndOfDay = value;
              _error = null;
            }),
          ),
          if (_error != null) NoticeBanner(tone: Tone.danger, message: _error!),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: _confirm,
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
