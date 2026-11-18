import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/widgets/rule_editor_scaffold.dart';
import '../../../device_sync/presentation/widgets/policy_sync_status_view.dart';
import '../../domain/entities/app_entry.dart';
import '../../domain/entities/app_list_filter.dart';
import '../../domain/entities/effective_app_state.dart';
import '../../domain/services/app_list_query.dart';
import '../../domain/services/app_rules_editing.dart';
import '../bloc/app_inventory/app_inventory_bloc.dart';
import '../bloc/app_management/app_management_bloc.dart';
import '../widgets/app_icon_view.dart';
import '../widgets/app_rule_sheet.dart';
import '../widgets/effective_app_state_ui.dart';

/// Lista dos apps instalados no aparelho, com o estado de cada um e a edicao por app.
///
/// Espera um [AppManagementBloc] (regras) e um [AppInventoryBloc] (inventario e filtros)
/// acima na arvore, ja iniciados para [device].
class AppsRulesPage extends StatefulWidget {
  const AppsRulesPage({required this.device, super.key});

  final ChildDevice device;

  @override
  State<AppsRulesPage> createState() => _AppsRulesPageState();
}

class _AppsRulesPageState extends State<AppsRulesPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = context.read<AppInventoryBloc>().state.filter.query;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openApp(AppsPolicy policy, AppEntry app) async {
    final AppManagementBloc rules = context.read<AppManagementBloc>();
    final AppRule? rule = await showAppRuleSheet(
      context,
      app: app,
      rule: policy.rules[app.package],
      state: effectiveStateOf(policy, app),
    );
    if (rule != null) {
      rules.add(AppRuleChanged(app: knownAppOf(app), rule: rule));
    }
  }

  Future<void> _applyToAll(List<AppEntry> listed, AppRuleState state) async {
    final AppManagementBloc rules = context.read<AppManagementBloc>();
    final List<AppEntry> targets = listed.where((AppEntry app) => !app.essential).toList();
    if (targets.isEmpty) {
      return;
    }
    final String verb = switch (state) {
      AppRuleState.allowed => 'Permitir',
      AppRuleState.blocked => 'Bloquear',
      AppRuleState.exception => 'Tornar exceção',
    };
    final bool confirmed = await confirmAction(
      context,
      title: '$verb ${targets.length} ${targets.length == 1 ? 'app' : 'apps'}?',
      message: 'A mudança vale para todos os apps da lista atual e só é enviada ao salvar.',
      confirmLabel: verb,
      destructive: state == AppRuleState.blocked,
    );
    if (confirmed) {
      rules.add(AppRulesAppliedToMany(apps: targets.map(knownAppOf).toList(), state: state));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppManagementBloc rules = context.read<AppManagementBloc>();
    return RuleEditorScaffold<AppManagementBloc, AppsPolicy>(
      title: 'Aplicativos',
      device: widget.device,
      onSave: () => rules.add(const AppManagementSaveRequested()),
      onDiscard: () => rules.add(const AppManagementDiscardRequested()),
      onRetry: () => rules.add(AppManagementStarted(widget.device.id)),
      body: (BuildContext context, AppsPolicy policy) {
        return BlocBuilder<AppInventoryBloc, AppInventoryState>(
          builder: (BuildContext context, AppInventoryState inventory) {
            return switch (inventory) {
              AppInventoryLoading() => const LoadingView(message: 'Carregando os apps do aparelho'),
              AppInventoryError(:final failure) => FailureView(
                error: failure,
                onRetry: () {
                  context.read<AppInventoryBloc>().add(const AppInventoryRetryRequested());
                },
              ),
              AppInventoryLoaded() => _buildList(context, policy, inventory),
            };
          },
        );
      },
    );
  }

  Widget _buildList(BuildContext context, AppsPolicy policy, AppInventoryLoaded inventory) {
    final ThemeData theme = Theme.of(context);
    final AppManagementBloc rules = context.read<AppManagementBloc>();
    final AppInventoryBloc list = context.read<AppInventoryBloc>();
    final AppListFilter filter = inventory.filter;
    final List<AppEntry> apps = inventory.inventory.apps;
    final List<AppEntry> visible = visibleApps(apps, policy, filter);
    final Set<AppCategory> categories = categoriesOf(apps);
    final bool narrowed = filter.isNarrowed;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList.list(
                children: <Widget>[
                  PolicySyncStatusView(status: widget.device.policySync),
                  const SizedBox(height: AppSpacing.md),
                  _NewAppsCard(
                    value: policy.defaultForNewApps,
                    onChanged: (NewAppDefault value) => rules.add(
                      NewAppDefaultChanged(
                        value: value,
                        installedApps: apps.map(knownAppOf).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _search,
                    onChanged: (String value) => list.add(AppListQueryChanged(value)),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome ou pacote',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar busca',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                list.add(const AppListQueryChanged(''));
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        for (final AppStateFilter option in AppStateFilter.values)
                          if (option != AppStateFilter.pending ||
                              policy.defaultForNewApps == NewAppDefault.blocked)
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: ChoiceChip(
                                label: Text(option.label),
                                selected: filter.state == option,
                                onSelected: (_) => list.add(AppListStateFilterChanged(option)),
                              ),
                            ),
                      ],
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PopupMenuButton<AppCategory?>(
                            tooltip: 'Filtrar por categoria',
                            onSelected: (AppCategory? value) {
                              list.add(AppListCategoryChanged(value));
                            },
                            itemBuilder: (BuildContext context) {
                              return <PopupMenuEntry<AppCategory?>>[
                                const PopupMenuItem<AppCategory?>(
                                  child: Text('Todas as categorias'),
                                ),
                                for (final AppCategory category in AppCategory.values)
                                  if (categories.contains(category))
                                    PopupMenuItem<AppCategory?>(
                                      value: category,
                                      child: Text(category.label),
                                    ),
                              ];
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(Icons.filter_list, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    filter.category?.label ?? 'Todas as categorias',
                                    style: theme.textTheme.labelLarge,
                                  ),
                                  const Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (narrowed && visible.isNotEmpty)
                        PopupMenuButton<AppRuleState>(
                          tooltip: 'Aplicar a todos da lista',
                          onSelected: (AppRuleState state) => _applyToAll(visible, state),
                          itemBuilder: (BuildContext context) {
                            return const <PopupMenuEntry<AppRuleState>>[
                              PopupMenuItem<AppRuleState>(
                                value: AppRuleState.allowed,
                                child: Text('Permitir todos da lista'),
                              ),
                              PopupMenuItem<AppRuleState>(
                                value: AppRuleState.blocked,
                                child: Text('Bloquear todos da lista'),
                              ),
                              PopupMenuItem<AppRuleState>(
                                value: AppRuleState.exception,
                                child: Text('Tornar todos exceção'),
                              ),
                            ];
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text('Aplicar a todos', style: theme.textTheme.labelLarge),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${visible.length} ${visible.length == 1 ? 'app' : 'apps'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
            if (visible.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.apps_outlined,
                  title: 'Nenhum app encontrado',
                  message:
                      'Ajuste a busca ou os filtros. A lista vem do aparelho da criança e é '
                      'atualizada a cada sincronização.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (BuildContext context, int index) {
                    return const SizedBox(height: AppSpacing.sm);
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final AppEntry app = visible[index];
                    return _AppTile(
                      app: app,
                      rule: policy.rules[app.package],
                      state: effectiveStateOf(policy, app),
                      onTap: () => _openApp(policy, app),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NewAppsCard extends StatelessWidget {
  const _NewAppsCard({required this.value, required this.onChanged});

  final NewAppDefault value;
  final ValueChanged<NewAppDefault> onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Apps instalados depois',
      subtitle: value == NewAppDefault.blocked
          ? 'Um app novo fica bloqueado até você aprovar. Os já instalados não mudam.'
          : 'Um app novo pode ser usado assim que for instalado.',
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<NewAppDefault>(
          showSelectedIcon: false,
          segments: const <ButtonSegment<NewAppDefault>>[
            ButtonSegment<NewAppDefault>(value: NewAppDefault.allowed, label: Text('Permitir')),
            ButtonSegment<NewAppDefault>(
              value: NewAppDefault.blocked,
              label: Text('Bloquear até aprovar'),
            ),
          ],
          selected: <NewAppDefault>{value},
          onSelectionChanged: (Set<NewAppDefault> selection) => onChanged(selection.first),
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app, required this.rule, required this.state, required this.onTap});

  final AppEntry app;
  final AppRule? rule;
  final EffectiveAppState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final int? limit = rule?.dailyLimitMinutes;
    final List<String> details = <String>[
      app.category.label,
      'hoje ${formatDurationMs(app.todayMs)}',
      if (limit != null) 'limite ${formatMinutes(limit)}',
      if (app.removed) 'removido do aparelho',
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>('app-${app.package}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              AppIconView.forApp(app, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      app.label,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(app.package, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(details.join(' · '), style: muted),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(label: state.label, tone: state.tone, icon: state.icon),
            ],
          ),
        ),
      ),
    );
  }
}
