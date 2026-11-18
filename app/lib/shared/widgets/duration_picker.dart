import 'package:material_ui/material_ui.dart';

import '../../core/time/formatters.dart';
import '../theme/app_theme.dart';

/// Abre o seletor de duracao em horas e minutos, com passo de 1 minuto. Devolve o total em
/// minutos, ou nulo se a pessoa cancelar.
Future<int?> showDurationPicker(
  BuildContext context, {
  required String title,
  required int initialMinutes,
  int minMinutes = 0,
  int maxMinutes = 1440,
  List<int> presets = const <int>[30, 60, 90, 120, 150, 180, 240],
  String? helper,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) {
      return DurationPickerSheet(
        title: title,
        initialMinutes: initialMinutes.clamp(minMinutes, maxMinutes),
        minMinutes: minMinutes,
        maxMinutes: maxMinutes,
        presets: presets,
        helper: helper,
      );
    },
  );
}

/// Conteudo do seletor de duracao: duas rodas (horas e minutos) e atalhos.
class DurationPickerSheet extends StatefulWidget {
  const DurationPickerSheet({
    required this.title,
    required this.initialMinutes,
    required this.minMinutes,
    required this.maxMinutes,
    required this.presets,
    this.helper,
    super.key,
  });

  final String title;
  final int initialMinutes;
  final int minMinutes;
  final int maxMinutes;
  final List<int> presets;
  final String? helper;

  @override
  State<DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<DurationPickerSheet> {
  late int _total = widget.initialMinutes;
  late final FixedExtentScrollController _hours = FixedExtentScrollController(
    initialItem: _total ~/ 60,
  );
  late final FixedExtentScrollController _minutes = FixedExtentScrollController(
    initialItem: _total % 60,
  );

  int get _maxHours => widget.maxMinutes ~/ 60;

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _onWheel({int? hours, int? minutes}) {
    final int next = (hours ?? _total ~/ 60) * 60 + (minutes ?? _total % 60);
    final int clamped = next.clamp(widget.minMinutes, widget.maxMinutes);
    setState(() => _total = clamped);
    if (clamped != next) {
      // O valor passou do limite (por exemplo 24h e alguns minutos): reposiciona as rodas.
      _moveWheels(clamped);
    }
  }

  void _moveWheels(int total) {
    if (_hours.hasClients && _hours.selectedItem != total ~/ 60) {
      _hours.jumpToItem(total ~/ 60);
    }
    if (_minutes.hasClients && _minutes.selectedItem != total % 60) {
      _minutes.jumpToItem(total % 60);
    }
  }

  void _applyPreset(int minutes) {
    setState(() => _total = minutes);
    _moveWheels(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<int> presets = widget.presets
        .where((int value) => value >= widget.minMinutes && value <= widget.maxMinutes)
        .toList();
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
          Text(widget.title, style: theme.textTheme.titleLarge),
          if (widget.helper != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.helper!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              formatMinutes(_total),
              key: const ValueKey<String>('duration-value'),
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _Wheel(
                key: const ValueKey<String>('duration-hours'),
                controller: _hours,
                count: _maxHours + 1,
                label: 'horas',
                value: _total ~/ 60,
                onChanged: (int value) => _onWheel(hours: value),
              ),
              const SizedBox(width: AppSpacing.xl),
              _Wheel(
                key: const ValueKey<String>('duration-minutes'),
                controller: _minutes,
                count: 60,
                label: 'minutos',
                value: _total % 60,
                onChanged: (int value) => _onWheel(minutes: value),
              ),
            ],
          ),
          if (presets.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text('Atalhos', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final int preset in presets)
                  ChoiceChip(
                    label: Text(formatMinutes(preset)),
                    selected: _total == preset,
                    onSelected: (_) => _applyPreset(preset),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  key: const ValueKey<String>('duration-confirm'),
                  onPressed: () => Navigator.of(context).pop(_total),
                  child: const Text('Confirmar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.count,
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  static const double _itemExtent = 44;

  final FixedExtentScrollController controller;
  final int count;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  void _step(int delta) {
    final int next = (value + delta).clamp(0, count - 1);
    if (next != value && controller.hasClients) {
      controller.animateToItem(
        next,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          container: true,
          label: label,
          value: '$value',
          increasedValue: '${(value + 1).clamp(0, count - 1)}',
          decreasedValue: '${(value - 1).clamp(0, count - 1)}',
          onIncrease: () => _step(1),
          onDecrease: () => _step(-1),
          child: ExcludeSemantics(
            child: SizedBox(
              width: 88,
              height: _itemExtent * 3,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    height: _itemExtent,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  ListWheelScrollView.useDelegate(
                    controller: controller,
                    itemExtent: _itemExtent,
                    diameterRatio: 1.8,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: onChanged,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: count,
                      builder: (BuildContext context, int index) {
                        final bool selected = index == value;
                        return Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                              color: selected
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Abre o seletor de horario em formato de 24 horas. Devolve hora e minuto, ou nulo.
Future<({int hour, int minute})?> pickTimeOfDay(
  BuildContext context, {
  required int hour,
  required int minute,
  String? helpText,
}) async {
  final TimeOfDay? picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59)),
    helpText: helpText,
    builder: (BuildContext context, Widget? child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
  if (picked == null) {
    return null;
  }
  return (hour: picked.hour, minute: picked.minute);
}
