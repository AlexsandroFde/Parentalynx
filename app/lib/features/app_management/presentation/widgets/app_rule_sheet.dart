import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../domain/entities/app_entry.dart';
import '../../domain/entities/effective_app_state.dart';
import '../../domain/services/app_rules_editing.dart';
import 'app_icon_view.dart';

/// Atalhos de limite proprio de um app, em minutos por dia.
const List<int> _appLimitPresets = <int>[15, 30, 45, 60, 90, 120];

/// Abre a folha de regra de um app. Devolve a regra escolhida, ou nulo se nada mudou.
Future<AppRule?> showAppRuleSheet(
  BuildContext context, {
  required AppEntry app,
  required AppRule? rule,
  required EffectiveAppState state,
}) {
  final String usage =
      'Hoje ${formatDurationMs(app.todayMs)} · 7 dias ${formatDurationMs(app.weekMs)}';
  return showAppSheet<AppRule>(
    context,
    title: app.label,
    subtitle: '${app.category.label}. $usage',
    builder: (BuildContext context) => _AppRuleForm(app: app, rule: rule, state: state),
  );
}

class _AppRuleForm extends StatefulWidget {
  const _AppRuleForm({required this.app, required this.rule, required this.state});

  final AppEntry app;
  final AppRule? rule;
  final EffectiveAppState state;

  @override
  State<_AppRuleForm> createState() => _AppRuleFormState();
}

class _AppRuleFormState extends State<_AppRuleForm> {
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
      presets: _appLimitPresets,
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
    Navigator.of(context)
        .pop(composeAppRule(state: state, countsTowardLimit: _counts, dailyLimitMinutes: _limit));
  }

  @override
  Widget build(BuildContext context) {
    final AppEntry app = widget.app;
    final bool essential = widget.state == EffectiveAppState.essential;
    final int? limit = _limit;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            AppIconView.forApp(app, size: AppSizes.avatarLg),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text('Identificador do app: ${app.package}', style: context.text.bodySmall),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (essential)
          const AppBanner(
            icon: AppIcons.lock,
            title: 'Função essencial do sistema',
            message:
                'Fica sempre disponível e não pode ser bloqueado, para que chamadas de '
                'emergência e o funcionamento do aparelho nunca sejam impedidos.',
          )
        else ...<Widget>[
          if (widget.state == EffectiveAppState.pendingApproval) ...<Widget>[
            const AppBanner(
              tone: Tone.warning,
              title: 'App novo aguardando sua decisão',
              message: 'Ele fica bloqueado até você escolher uma das opções abaixo.',
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppListGroup(
            dividerIndent: AppSpacing.lg + AppSizes.iconLg + AppSpacing.md,
            children: <Widget>[
              AppRadioRow<AppRuleState>(
                value: AppRuleState.allowed,
                groupValue: _state,
                title: 'Permitido',
                subtitle: 'Pode ser usado dentro do limite de tempo e dos horários.',
                trailing: const AppIconTile(icon: AppIcons.check, tone: Tone.neutral),
                onChanged: (AppRuleState value) => setState(() => _state = value),
              ),
              AppRadioRow<AppRuleState>(
                value: AppRuleState.blocked,
                groupValue: _state,
                title: 'Bloqueado',
                subtitle: 'Não pode ser aberto.',
                trailing: const AppIconTile(icon: AppIcons.blocked, tone: Tone.danger),
                onChanged: (AppRuleState value) => setState(() => _state = value),
              ),
              AppRadioRow<AppRuleState>(
                value: AppRuleState.exception,
                groupValue: _state,
                title: 'Exceção',
                subtitle:
                    'Continua disponível com o limite atingido, fora do horário e com o '
                    'aparelho pausado.',
                trailing: const AppIconTile(icon: AppIcons.exception, tone: Tone.success),
                onChanged: (AppRuleState value) => setState(() => _state = value),
              ),
            ],
          ),
          if (_state == AppRuleState.exception) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            AppListGroup(
              children: <Widget>[
                AppSwitchRow(
                  icon: AppIcons.dailyLimit,
                  title: 'Descontar do limite diário',
                  subtitle: _counts
                      ? 'O tempo neste app consome o tempo do dia.'
                      : 'O tempo neste app não consome o tempo do dia.',
                  value: _counts,
                  onChanged: (bool value) => setState(() => _counts = value),
                ),
              ],
            ),
          ],
          if (_state == AppRuleState.allowed || _state == AppRuleState.exception) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            AppListGroup(
              children: <Widget>[
                AppSwitchRow(
                  icon: AppIcons.timeRunningOut,
                  title: 'Limite próprio para este app',
                  subtitle: limit == null
                      ? 'Sem limite próprio.'
                      : 'No máximo ${formatMinutes(limit)} por dia.',
                  value: limit != null,
                  onChanged: (bool value) => setState(() => _limit = value ? 60 : null),
                ),
                if (limit != null)
                  AppListRow(
                    title: 'Tempo por dia',
                    titleStyle: context.text.bodyLarge,
                    trailing: Text(formatMinutes(limit), style: context.textStyles.metricSmall),
                    showChevron: true,
                    onTap: _pickLimit,
                  ),
              ],
            ),
            if (limit != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              AppChoiceChips<int>(
                choices: <AppChoice<int>>[
                  for (final int minutes in _appLimitPresets)
                    AppChoice<int>(value: minutes, label: formatMinutes(minutes)),
                ],
                selected: _appLimitPresets.contains(limit) ? limit : null,
                onSelected: (int minutes) => setState(() => _limit = minutes),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton.primary(
            key: const ValueKey<String>('app-rule-apply'),
            label: 'Concluir',
            expand: true,
            onPressed: _state == null ? null : _apply,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A mudança vai para o aparelho quando você salvar a lista de apps.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        ],
      ],
    );
  }
}
