import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/editing/policy_section_state.dart';
import '../../../device_policy/presentation/widgets/rule_editor_scaffold.dart';
import '../../domain/entities/app_entry.dart';
import '../../domain/services/app_list_query.dart';
import '../../domain/services/app_rules_editing.dart';
import '../bloc/app_inventory/app_inventory_bloc.dart';
import '../bloc/app_management/app_management_bloc.dart';
import '../widgets/app_icon_view.dart';

const List<HelpTopic> _exceptionsHelp = <HelpTopic>[
  HelpTopic(
    title: 'O que é uma exceção?',
    body:
        'Um app que continua funcionando com o limite diário atingido, fora do horário '
        'permitido, nos períodos de bloqueio e com o aparelho pausado. Use para apps da escola '
        'ou de mensagens da família.',
  ),
  HelpTopic(
    title: 'O tempo nas exceções conta no limite?',
    body:
        'Por padrão, não. Na lista de apps você escolhe, app por app, se o tempo na exceção '
        'desconta do limite diário. Um limite próprio do app continua valendo.',
  ),
  HelpTopic(
    title: 'O que são as funções essenciais?',
    body:
        'Telefone, chamadas de emergência, tela inicial, teclado, permissões e recursos de '
        'segurança do sistema. O ParentaLynx nunca bloqueia esses itens, em nenhuma situação.',
  ),
];

/// O que continua disponivel durante um bloqueio geral: o que o sistema sempre mantem e os
/// apps que o responsavel liberou como excecao.
///
/// Espera um [AppManagementBloc] e um [AppInventoryBloc] acima na arvore, ja iniciados.
class ExceptionsPage extends StatelessWidget {
  const ExceptionsPage({required this.device, super.key});

  final ChildDevice device;

  void _chooseApps(BuildContext context) {
    final AppManagementState state = context.read<AppManagementBloc>().state;
    if (state is PolicySectionEditing<AppsPolicy> && state.isDirty) {
      // A lista de apps edita as mesmas regras: com alteracoes pendentes aqui, uma das duas
      // telas perderia o que foi feito.
      showAppSnackBar(
        context,
        'Salve ou descarte as alterações antes de abrir a lista de apps.',
        tone: Tone.warning,
      );
      return;
    }
    context.push(RulesPaths.apps);
  }

  void _remove(BuildContext context, String package, AppEntry? app, AppRule rule) {
    final AppManagementBloc rules = context.read<AppManagementBloc>();
    final KnownApp known = (package: package, system: app?.system ?? false, essential: false);
    rules.add(AppRuleChanged(app: known, rule: rule.withState(AppRuleState.allowed)));
    showAppSnackBar(
      context,
      '${app?.label ?? package} não é mais exceção.',
      actionLabel: 'Desfazer',
      onAction: () => rules.add(AppRuleChanged(app: known, rule: rule)),
    );
  }

  Future<void> _showEssentials(BuildContext context, List<AppEntry> essentials) {
    return showAppSheet<void>(
      context,
      title: 'Itens essenciais deste aparelho',
      subtitle: 'Sempre disponíveis. Não podem ser bloqueados.',
      builder: (BuildContext context) {
        return AppListGroup(
          children: <Widget>[
            for (final AppEntry app in essentials)
              AppListRow(
                leading: AppIconView.forApp(app, size: AppSizes.iconTile),
                title: app.label,
                titleStyle: context.text.bodyLarge,
                trailing: const Icon(AppIcons.lock, size: AppSizes.iconSm),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppManagementBloc rules = context.read<AppManagementBloc>();
    return RuleEditorScaffold<AppManagementBloc, AppsPolicy>(
      title: 'Exceções e funções essenciais',
      description: 'O que continua funcionando mesmo com o celular bloqueado.',
      device: device,
      helpTopics: _exceptionsHelp,
      onSave: () => rules.add(const AppManagementSaveRequested()),
      onDiscard: () => rules.add(const AppManagementDiscardRequested()),
      onRetry: () => rules.add(AppManagementStarted(device.id)),
      onRestoreRejected: () => rules.add(const AppManagementRejectedChangesRestored()),
      children: (BuildContext context, AppsPolicy apps) {
        final List<AppEntry> inventory = context.watch<AppInventoryBloc>().state.appsOrEmpty;
        final Map<String, AppEntry> byPackage = <String, AppEntry>{
          for (final AppEntry app in inventory) app.package: app,
        };
        final List<MapEntry<String, AppRule>> exceptions = exceptionRules(apps);
        final List<AppEntry> essentials = essentialApps(inventory);

        return <Widget>[
          AppSection(
            title: 'Liberados por você',
            subtitle:
                'Funcionam com o limite atingido, fora do horário, nos períodos de bloqueio e '
                'com o aparelho pausado.',
            child: exceptions.isEmpty
                ? AppPanel(
                    child: EmptyState(
                      compact: true,
                      icon: AppIcons.exception,
                      tone: Tone.success,
                      title: 'Nenhum app liberado',
                      message:
                          'Marque como exceção os apps que devem funcionar sempre, como os da '
                          'escola e os de mensagens da família.',
                      actionLabel: 'Escolher apps',
                      onAction: () => _chooseApps(context),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AppListGroup(
                        children: <Widget>[
                          for (final MapEntry<String, AppRule> entry in exceptions)
                            _ExceptionRow(
                              package: entry.key,
                              app: byPackage[entry.key],
                              rule: entry.value,
                              onRemove: () {
                                _remove(context, entry.key, byPackage[entry.key], entry.value);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AppButton.secondary(
                          label: 'Escolher outros apps',
                          icon: AppIcons.apps,
                          size: AppButtonSize.compact,
                          onPressed: () => _chooseApps(context),
                        ),
                      ),
                    ],
                  ),
          ),
          const SectionGap(),
          AppSection(
            title: 'Sempre disponíveis',
            subtitle: 'Garantido pelo ParentaLynx. Não pode ser desligado.',
            child: AppListGroup(
              children: <Widget>[
                const _FixedRow(
                  icon: AppIcons.emergency,
                  title: 'Chamadas de emergência',
                  description: 'Nunca são bloqueadas, em nenhuma situação.',
                ),
                const _FixedRow(
                  icon: AppIcons.phoneCall,
                  title: 'Telefone',
                  description: 'Fazer e receber ligações continua possível.',
                ),
                const _FixedRow(
                  icon: AppIcons.advanced,
                  title: 'Funções essenciais do sistema',
                  description:
                      'Tela inicial, teclado, permissões, alertas de emergência e recursos de '
                      'segurança.',
                ),
                const _FixedRow(
                  icon: AppIcons.protection,
                  title: 'ParentaLynx',
                  description: 'A criança vê as regras e pode pedir mais tempo.',
                ),
                if (essentials.isNotEmpty)
                  AppListRow(
                    leading: const AppIconTile(icon: AppIcons.list, tone: Tone.neutral),
                    title: 'Itens essenciais deste aparelho',
                    subtitle: essentials.length == 1
                        ? '1 item, como ${essentials.first.label}'
                        : '${essentials.length} itens, como ${essentials.first.label}',
                    onTap: () => _showEssentials(context, essentials),
                  ),
              ],
            ),
          ),
        ];
      },
    );
  }
}

class _FixedRow extends StatelessWidget {
  const _FixedRow({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      leading: AppIconTile(icon: icon, tone: Tone.success),
      title: title,
      subtitle: description,
      trailing: Semantics(
        label: 'Sempre disponível',
        child: Icon(AppIcons.lock, size: AppSizes.iconSm, color: context.colors.textSecondary),
      ),
    );
  }
}

class _ExceptionRow extends StatelessWidget {
  const _ExceptionRow({
    required this.package,
    required this.app,
    required this.rule,
    required this.onRemove,
  });

  final String package;
  final AppEntry? app;
  final AppRule rule;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final String label = app?.label ?? package;
    final int? limit = rule.dailyLimitMinutes;
    final List<String> notes = <String>[
      if (rule.countsTowardLimit) 'Desconta do limite diário' else 'Não desconta do limite',
      if (limit != null) 'limite próprio de ${formatMinutes(limit)}',
    ];
    return AppListRow(
      leading: AppIconView(
        package: package,
        label: label,
        iconPath: app?.iconPath,
        size: AppSizes.iconTile,
      ),
      title: label,
      subtitle: notes.join(' · '),
      trailing: AppIconButton(
        icon: AppIcons.removeCircle,
        tooltip: 'Tirar $label das exceções',
        onPressed: onRemove,
      ),
    );
  }
}
