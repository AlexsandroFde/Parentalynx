import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/widgets/rule_editor_scaffold.dart';
import '../../domain/entities/app_entry.dart';
import '../../domain/services/app_list_query.dart';
import '../bloc/app_inventory/app_inventory_bloc.dart';
import '../bloc/app_management/app_management_bloc.dart';
import '../widgets/app_icon_view.dart';

/// O que continua disponivel durante um bloqueio geral: o que o sistema sempre mantem e os
/// apps que o responsavel liberou como excecao.
///
/// Espera um [AppManagementBloc] e um [AppInventoryBloc] acima na arvore, ja iniciados.
class ExceptionsPage extends StatelessWidget {
  const ExceptionsPage({required this.device, super.key});

  final ChildDevice device;

  @override
  Widget build(BuildContext context) {
    final AppManagementBloc rules = context.read<AppManagementBloc>();
    return RuleEditorScaffold<AppManagementBloc, AppsPolicy>(
      title: 'Exceções e funções essenciais',
      device: device,
      onSave: () => rules.add(const AppManagementSaveRequested()),
      onDiscard: () => rules.add(const AppManagementDiscardRequested()),
      onRetry: () => rules.add(AppManagementStarted(device.id)),
      children: (BuildContext context, AppsPolicy apps) {
        final ThemeData theme = Theme.of(context);
        final List<AppEntry> inventory = context.watch<AppInventoryBloc>().state.appsOrEmpty;
        final Map<String, AppEntry> byPackage = <String, AppEntry>{
          for (final AppEntry app in inventory) app.package: app,
        };
        final List<MapEntry<String, AppRule>> exceptions = exceptionRules(apps);
        final List<AppEntry> essentials = essentialApps(inventory);

        return <Widget>[
          const NoticeBanner(
            message:
                'As exceções valem com o limite diário atingido, fora do horário permitido, '
                'nos períodos de bloqueio e com o aparelho pausado.',
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Sempre disponíveis',
            subtitle: 'Garantido pelo aplicativo. Não pode ser desligado.',
            child: Column(
              children: <Widget>[
                const _FixedRow(
                  icon: Icons.emergency_outlined,
                  title: 'Chamadas de emergência',
                  description: 'Nunca são bloqueadas, em nenhuma situação.',
                ),
                const _FixedRow(
                  icon: Icons.phone_outlined,
                  title: 'Telefone',
                  description: 'Fazer e receber ligações continua possível.',
                ),
                const _FixedRow(
                  icon: Icons.settings_suggest_outlined,
                  title: 'Funções essenciais do sistema',
                  description:
                      'Tela inicial, teclado, permissões, alertas de emergência e '
                      'recursos de segurança.',
                ),
                const _FixedRow(
                  icon: Icons.shield_outlined,
                  title: 'ParentaLynx',
                  description: 'A criança vê as regras e pode pedir mais tempo.',
                ),
                if (essentials.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Itens essenciais deste aparelho (${essentials.length})',
                      style: theme.textTheme.labelLarge,
                    ),
                    children: <Widget>[
                      for (final AppEntry app in essentials)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: AppIconView.forApp(app, size: 32),
                          title: Text(app.label),
                          subtitle: Text(app.package),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Apps liberados por você',
            subtitle: 'Marcados como exceção nas regras de aplicativos.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (exceptions.isEmpty)
                  Text(
                    'Nenhum app liberado. Marque como exceção os apps que devem funcionar '
                    'mesmo com o limite atingido, como os da escola e os de mensagens da '
                    'família.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final MapEntry<String, AppRule> entry in exceptions)
                    _ExceptionRow(
                      package: entry.key,
                      app: byPackage[entry.key],
                      rule: entry.value,
                      onRemove: () => rules.add(
                        AppRuleChanged(
                          app: (
                            package: entry.key,
                            system: byPackage[entry.key]?.system ?? false,
                            essential: false,
                          ),
                          rule: entry.value.withState(AppRuleState.allowed),
                        ),
                      ),
                    ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => context.push(RulesPaths.apps),
                  icon: const Icon(Icons.apps_outlined),
                  label: const Text('Escolher apps'),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(description),
      trailing: const Icon(Icons.lock_outline, size: 18),
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
      if (rule.countsTowardLimit) 'desconta do limite' else 'não desconta do limite',
      if (limit != null) 'limite próprio ${formatMinutes(limit)}',
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AppIconView(package: package, label: label, iconPath: app?.iconPath),
      title: Text(label),
      subtitle: Text(notes.join(', ')),
      trailing: IconButton(
        tooltip: 'Remover $label das exceções',
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: onRemove,
      ),
    );
  }
}
