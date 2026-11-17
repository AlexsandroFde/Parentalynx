import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/domain/policy.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../apps/data/apps_repository.dart';
import '../../apps/domain/app_entry.dart';
import '../../apps/presentation/app_icon.dart';
import '../domain/app_rules_editing.dart';
import '../rules_paths.dart';
import 'widgets/rule_scaffold.dart';

/// O que continua disponivel durante um bloqueio geral: o que o sistema sempre mantem e os
/// apps que o responsavel liberou como excecao.
class ExceptionsPage extends ConsumerWidget {
  const ExceptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RuleEditorScaffold(
      title: 'Exceções e funções essenciais',
      children: (BuildContext context, RuleEditing editing) {
        final ThemeData theme = Theme.of(context);
        final List<AppEntry> inventory =
            ref.watch(deviceAppsProvider(editing.device.id)).value?.apps ?? const <AppEntry>[];
        final Map<String, AppEntry> byPackage = <String, AppEntry>{
          for (final AppEntry app in inventory) app.package: app,
        };
        final AppsPolicy apps = editing.draft.apps;
        final List<MapEntry<String, AppRule>> exceptions = apps.rules.entries
            .where((MapEntry<String, AppRule> entry) => entry.value.state == AppRuleState.exception)
            .toList();
        final List<AppEntry> essentials = inventory
            .where((AppEntry app) => app.essential && app.launchable)
            .toList();

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
                      onRemove: () => editing.update(
                        (Policy p) => p.copyWith(
                          apps: setAppRule(
                            p.apps,
                            entry.key,
                            entry.value.withState(AppRuleState.allowed),
                            system: byPackage[entry.key]?.system ?? false,
                          ),
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
      leading: AppIconView(package: package, label: label, iconUrl: app?.iconUrl),
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
