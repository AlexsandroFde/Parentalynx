import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/duration_picker.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';

/// Por quanto tempo pausar o aparelho.
enum PauseChoice {
  thirty('Por 30 minutos', Duration(minutes: 30)),
  hour('Por 1 hora', Duration(hours: 1)),
  twoHours('Por 2 horas', Duration(hours: 2)),
  untilResumed('Até eu retomar', null);

  const PauseChoice(this.label, this.duration);

  final String label;

  /// Nulo para "ate eu retomar".
  final Duration? duration;
}

/// Pergunta por quanto tempo pausar o aparelho. Nulo quando a pessoa desiste.
Future<PauseChoice?> showPauseChoiceDialog(BuildContext context, ChildDevice device) {
  return showDialog<PauseChoice>(
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
          for (final PauseChoice option in PauseChoice.values)
            SimpleDialogOption(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              onPressed: () => Navigator.of(context).pop(option),
              child: Text(option.label),
            ),
        ],
      );
    },
  );
}

/// Pede um valor personalizado de tempo extra para hoje. Nulo quando a pessoa desiste.
Future<int?> showCustomExtraTimePicker(BuildContext context) {
  return showDurationPicker(
    context,
    title: 'Tempo extra para hoje',
    helper: 'Soma ao limite de hoje. Amanhã o limite volta ao normal.',
    initialMinutes: 45,
    minMinutes: 1,
    maxMinutes: 720,
    presets: const <int>[10, 20, 45, 90, 120],
  );
}

/// Escolha da suspensao temporaria de regras.
typedef SuspensionChoice = ({int minutes, List<SuspensionScope> scopes});

/// Abre a folha de suspensao temporaria de regras. Nulo quando a pessoa desiste.
Future<SuspensionChoice?> showSuspendRulesSheet(BuildContext context) {
  return showModalBottomSheet<SuspensionChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => const _SuspendSheet(),
  );
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
