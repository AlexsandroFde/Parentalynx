import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';

/// Por quanto tempo pausar o aparelho.
enum PauseChoice {
  thirty('Por 30 minutos', 'Pausar por 30 minutos', Duration(minutes: 30)),
  hour('Por 1 hora', 'Pausar por 1 hora', Duration(hours: 1)),
  twoHours('Por 2 horas', 'Pausar por 2 horas', Duration(hours: 2)),
  untilResumed('Até eu retomar', 'Pausar até eu retomar', null);

  const PauseChoice(this.label, this.confirmLabel, this.duration);

  final String label;

  /// Rotulo do botao de confirmar, que nomeia a acao e o prazo.
  final String confirmLabel;

  /// Nulo para "ate eu retomar".
  final Duration? duration;
}

/// Confirma a pausa do aparelho e o prazo. Nulo quando a pessoa desiste.
///
/// A pausa so e enviada depois desta confirmacao, que mostra o que continua funcionando e
/// quando o aparelho volta ao normal.
Future<PauseChoice?> showPauseSheet(
  BuildContext context, {
  required ChildDevice device,
  required DateTime now,
}) {
  return showAppSheet<PauseChoice>(
    context,
    title: 'Pausar o aparelho de ${device.displayName}?',
    subtitle:
        'Tudo fica bloqueado, menos as exceções. Chamadas de emergência nunca são bloqueadas.',
    builder: (BuildContext context) => _PauseChooser(now: now),
  );
}

class _PauseChooser extends StatefulWidget {
  const _PauseChooser({required this.now});

  final DateTime now;

  @override
  State<_PauseChooser> createState() => _PauseChooserState();
}

class _PauseChooserState extends State<_PauseChooser> {
  PauseChoice _choice = PauseChoice.hour;

  String _until(PauseChoice choice) {
    final Duration? duration = choice.duration;
    if (duration == null) {
      return 'Você retoma pelo painel quando quiser.';
    }
    return 'Volta ao normal às ${formatClock(widget.now.add(duration))}.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppListGroup(
          dividerIndent: AppSpacing.lg + AppSizes.iconLg + AppSpacing.md,
          children: <Widget>[
            for (final PauseChoice option in PauseChoice.values)
              AppRadioRow<PauseChoice>(
                title: option.label,
                subtitle: _until(option),
                value: option,
                groupValue: _choice,
                onChanged: (PauseChoice value) => setState(() => _choice = value),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton.primary(
          label: _choice.confirmLabel,
          icon: AppIcons.pause,
          expand: true,
          onPressed: () => Navigator.of(context).pop(_choice),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton.tertiary(
          label: 'Cancelar',
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
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

/// Confirma a suspensao temporaria de regras: por quanto tempo, o que deixa de valer e quando
/// volta. Nulo quando a pessoa desiste.
Future<SuspensionChoice?> showSuspendRulesSheet(
  BuildContext context, {
  required ChildDevice device,
  required DateTime now,
}) {
  return showAppSheet<SuspensionChoice>(
    context,
    title: 'Suspender regras',
    subtitle:
        'As regras escolhidas deixam de valer no aparelho de ${device.displayName} e voltam '
        'sozinhas no fim do prazo.',
    builder: (BuildContext context) => _SuspendChooser(now: now),
  );
}

class _SuspendChooser extends StatefulWidget {
  const _SuspendChooser({required this.now});

  final DateTime now;

  @override
  State<_SuspendChooser> createState() => _SuspendChooserState();
}

class _SuspendChooserState extends State<_SuspendChooser> {
  static const List<int> _durations = <int>[30, 60, 120, 240];

  int _minutes = 60;
  bool _showScopeError = false;
  final Set<SuspensionScope> _scopes = <SuspensionScope>{
    SuspensionScope.dailyLimit,
    SuspensionScope.schedules,
  };

  void _toggle(SuspensionScope scope, bool checked) {
    setState(() {
      if (checked) {
        _scopes.add(scope);
      } else {
        _scopes.remove(scope);
      }
      _showScopeError = false;
    });
  }

  void _confirm() {
    if (_scopes.isEmpty) {
      setState(() => _showScopeError = true);
      return;
    }
    Navigator.of(context)
        .pop((minutes: _minutes, scopes: SuspensionScope.values.where(_scopes.contains).toList()));
  }

  @override
  Widget build(BuildContext context) {
    final DateTime end = widget.now.add(Duration(minutes: _minutes));
    final String back = formatReleaseTime(end.millisecondsSinceEpoch, now: widget.now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(header: true, child: Text('Por quanto tempo', style: context.text.titleSmall)),
        const SizedBox(height: AppSpacing.sm),
        AppChoiceChips<int>(
          choices: <AppChoice<int>>[
            for (final int option in _durations)
              AppChoice<int>(value: option, label: formatMinutes(option)),
          ],
          selected: _minutes,
          onSelected: (int value) => setState(() => _minutes = value),
        ),
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          header: true,
          child: Text('O que deixa de valer', style: context.text.titleSmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppListGroup(
          dividerIndent: AppSpacing.lg + AppSizes.minTapTarget + AppSpacing.md,
          children: <Widget>[
            for (final SuspensionScope scope in SuspensionScope.values)
              AppCheckboxRow(
                title: scope.label,
                value: _scopes.contains(scope),
                onChanged: (bool checked) => _toggle(scope, checked),
              ),
          ],
        ),
        if (_showScopeError) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              'Escolha pelo menos uma regra para suspender.',
              style: context.text.bodySmall?.copyWith(color: context.colors.danger),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'As regras voltam a valer $back. O tempo usado com o limite suspenso não desconta da '
          'cota de hoje.',
          style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton.primary(
          label: 'Suspender por ${formatMinutes(_minutes)}',
          icon: AppIcons.unlock,
          expand: true,
          onPressed: _confirm,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton.tertiary(
          label: 'Cancelar',
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
