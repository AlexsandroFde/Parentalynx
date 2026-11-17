import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/domain/policy.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../apps/domain/app_entry.dart';
import '../../apps/presentation/app_icon.dart';
import '../domain/app_rules_editing.dart';
import 'widgets/duration_picker.dart';
import 'widgets/rule_scaffold.dart';

/// Cor, icone e texto de cada estado efetivo de um app.
extension EffectiveAppStateUi on EffectiveAppState {
  Tone get tone {
    return switch (this) {
      EffectiveAppState.allowed => Tone.neutral,
      EffectiveAppState.blocked => Tone.danger,
      EffectiveAppState.exception => Tone.success,
      EffectiveAppState.pendingApproval => Tone.warning,
      EffectiveAppState.essential => Tone.info,
    };
  }

  IconData get icon {
    return switch (this) {
      EffectiveAppState.allowed => Icons.check,
      EffectiveAppState.blocked => Icons.block,
      EffectiveAppState.exception => Icons.verified_outlined,
      EffectiveAppState.pendingApproval => Icons.hourglass_empty,
      EffectiveAppState.essential => Icons.lock_outline,
    };
  }
}

/// Abre a folha de regra de um app. Devolve a regra escolhida, ou nulo se nada mudou.
Future<AppRule?> showAppRuleSheet(
  BuildContext context, {
  required AppEntry app,
  required AppRule? rule,
  required EffectiveAppState state,
}) {
  return showModalBottomSheet<AppRule>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => _AppRuleSheet(app: app, rule: rule, state: state),
  );
}

class _AppRuleSheet extends StatefulWidget {
  const _AppRuleSheet({required this.app, required this.rule, required this.state});

  final AppEntry app;
  final AppRule? rule;
  final EffectiveAppState state;

  @override
  State<_AppRuleSheet> createState() => _AppRuleSheetState();
}

class _AppRuleSheetState extends State<_AppRuleSheet> {
  late AppRuleState? _state = switch (widget.state) {
    EffectiveAppState.allowed => AppRuleState.allowed,
    EffectiveAppState.blocked => AppRuleState.blocked,
    EffectiveAppState.exception => AppRuleState.exception,
    EffectiveAppState.pendingApproval || EffectiveAppState.essential => null,
  };
  late bool _counts = widget.rule?.countsTowardLimit ?? false;
  late int? _limit = widget.rule?.dailyLimitMinutes;

  Future<void> _pickLimit() async {
    final int? minutes = await showDurationPicker(
      context,
      title: 'Limite de ${widget.app.label}',
      helper: 'Tempo máximo deste app por dia.',
      initialMinutes: _limit ?? 60,
      minMinutes: 1,
      presets: const <int>[15, 30, 45, 60, 90, 120],
    );
    if (minutes != null) {
      setState(() => _limit = minutes);
    }
  }

  void _apply() {
    final AppRuleState? state = _state;
    if (state == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(
      AppRule(
        state: state,
        countsTowardLimit: state == AppRuleState.exception && _counts,
        dailyLimitMinutes: state == AppRuleState.blocked ? null : _limit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppEntry app = widget.app;
    final bool essential = widget.state == EffectiveAppState.essential;
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
          Row(
            children: <Widget>[
              AppIconView.forApp(app, size: 52),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(app.label, style: theme.textTheme.titleLarge),
                    Text(
                      app.package,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${app.category.label}. Hoje ${formatDurationMs(app.todayMs)}, '
                      '7 dias ${formatDurationMs(app.weekMs)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (essential)
            const NoticeBanner(
              icon: Icons.lock_outline,
              title: 'Função essencial do sistema',
              message:
                  'Este item fica sempre disponível e não pode ser bloqueado, para que '
                  'chamadas de emergência e o funcionamento do aparelho nunca sejam impedidos.',
            )
          else ...<Widget>[
            if (widget.state == EffectiveAppState.pendingApproval) ...<Widget>[
              const NoticeBanner(
                tone: Tone.warning,
                title: 'App novo aguardando sua decisão',
                message: 'Ele fica bloqueado até você escolher uma das opções abaixo.',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            _Option(
              selected: _state == AppRuleState.allowed,
              icon: Icons.check_circle_outline,
              title: 'Permitido',
              description: 'Pode ser usado dentro do limite de tempo e dos horários.',
              onTap: () => setState(() => _state = AppRuleState.allowed),
            ),
            _Option(
              selected: _state == AppRuleState.blocked,
              icon: Icons.block,
              title: 'Bloqueado',
              description: 'Não pode ser aberto.',
              onTap: () => setState(() => _state = AppRuleState.blocked),
            ),
            _Option(
              selected: _state == AppRuleState.exception,
              icon: Icons.verified_outlined,
              title: 'Exceção',
              description:
                  'Continua disponível com o limite atingido, fora do horário e com o '
                  'aparelho pausado.',
              onTap: () => setState(() => _state = AppRuleState.exception),
            ),
            if (_state == AppRuleState.exception)
              SwitchRow(
                title: 'Descontar do limite diário',
                subtitle: 'Desligado, o tempo neste app não consome a cota do dia.',
                value: _counts,
                onChanged: (bool value) => setState(() => _counts = value),
              ),
            if (_state == AppRuleState.allowed || _state == AppRuleState.exception) ...<Widget>[
              SwitchRow(
                title: 'Limite próprio para este app',
                subtitle: _limit == null
                    ? 'Sem limite próprio.'
                    : 'No máximo ${formatMinutes(_limit!)} por dia.',
                value: _limit != null,
                onChanged: (bool value) => setState(() => _limit = value ? 60 : null),
              ),
              if (_limit != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _pickLimit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text('Alterar (${formatMinutes(_limit!)})'),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const ValueKey<String>('app-rule-apply'),
              onPressed: _state == null ? null : _apply,
              child: const Text('Aplicar'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        button: true,
        child: Material(
          color: selected ? scheme.primaryContainer.withValues(alpha: 0.18) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: theme.textTheme.titleSmall),
                        Text(
                          description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
