import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/widgets/rule_editor_scaffold.dart';
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

const List<HelpTopic> _appsHelp = <HelpTopic>[
  HelpTopic(
    title: 'Permitido, bloqueado ou exceção?',
    body:
        'Permitido segue o limite de tempo e os horários. Bloqueado não abre. Exceção continua '
        'funcionando com o limite atingido, fora do horário e com o aparelho pausado, como um '
        'app da escola ou de mensagens da família.',
  ),
  HelpTopic(
    title: 'O que é o limite próprio?',
    body:
        'Um tempo máximo por dia só para aquele app. Ele vale junto com o limite diário: quando '
        'acaba, o app fecha mesmo que ainda haja tempo para o resto.',
  ),
  HelpTopic(
    title: 'E as funções essenciais?',
    body:
        'Telefone, emergência e partes do sistema nunca são bloqueados, para que o aparelho '
        'continue funcionando e as chamadas de emergência sejam sempre possíveis.',
  ),
];

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

  Future<void> _openNewApps(AppsPolicy policy, List<AppEntry> apps) async {
    final AppManagementBloc rules = context.read<AppManagementBloc>();
    final NewAppDefault? value = await showAppSheet<NewAppDefault>(
      context,
      title: 'Apps instalados depois',
      subtitle: 'Os apps que já estão no aparelho não mudam.',
      builder: (BuildContext context) {
        void choose(NewAppDefault value) => Navigator.of(context).pop(value);
        return AppListGroup(
          dividerIndent: AppSpacing.lg + AppSizes.iconLg + AppSpacing.md,
          children: <Widget>[
            AppRadioRow<NewAppDefault>(
              value: NewAppDefault.allowed,
              groupValue: policy.defaultForNewApps,
              title: 'Liberar na hora',
              subtitle: 'Um app novo pode ser usado assim que for instalado.',
              onChanged: choose,
            ),
            AppRadioRow<NewAppDefault>(
              value: NewAppDefault.blocked,
              groupValue: policy.defaultForNewApps,
              title: 'Bloquear até você aprovar',
              subtitle: 'Um app novo fica bloqueado até você decidir nesta lista.',
              onChanged: choose,
            ),
          ],
        );
      },
    );
    if (value != null) {
      rules.add(NewAppDefaultChanged(value: value, installedApps: apps.map(knownAppOf).toList()));
    }
  }

  Future<void> _applyToAll(List<AppEntry> listed, AppRuleState state) async {
    final AppManagementBloc rules = context.read<AppManagementBloc>();
    final List<AppEntry> targets = listed.where((AppEntry app) => !app.essential).toList();
    if (targets.isEmpty) {
      return;
    }
    final int count = targets.length;
    final String apps = '$count ${count == 1 ? 'app' : 'apps'}';
    final String verb = switch (state) {
      AppRuleState.allowed => 'Permitir',
      AppRuleState.blocked => 'Bloquear',
      AppRuleState.exception => 'Tornar exceção',
    };
    final bool confirmed = await showConfirmDialog(
      context,
      title: '$verb $apps?',
      message: 'Vale para os apps que aparecem agora na lista, com a busca e os filtros.',
      consequence: 'Nada vai para o aparelho até você salvar. Para voltar atrás, use Descartar.',
      confirmLabel: '$verb $apps',
      destructive: state == AppRuleState.blocked,
      icon: switch (state) {
        AppRuleState.allowed => AppIcons.check,
        AppRuleState.blocked => AppIcons.blocked,
        AppRuleState.exception => AppIcons.exception,
      },
    );
    if (confirmed) {
      rules.add(AppRulesAppliedToMany(apps: targets.map(knownAppOf).toList(), state: state));
    }
  }

  void _clearFilters() {
    final AppInventoryBloc list = context.read<AppInventoryBloc>();
    _search.clear();
    list
      ..add(const AppListQueryChanged(''))
      ..add(const AppListStateFilterChanged(AppStateFilter.all))
      ..add(const AppListCategoryChanged(null));
  }

  @override
  Widget build(BuildContext context) {
    final AppManagementBloc rules = context.read<AppManagementBloc>();
    return RuleEditorScaffold<AppManagementBloc, AppsPolicy>(
      title: 'Aplicativos',
      description: 'O que ${widget.device.displayName} pode abrir no celular e por quanto tempo.',
      device: widget.device,
      helpTopics: _appsHelp,
      onSave: () => rules.add(const AppManagementSaveRequested()),
      onDiscard: () => rules.add(const AppManagementDiscardRequested()),
      onRetry: () => rules.add(AppManagementStarted(widget.device.id)),
      onRestoreRejected: () => rules.add(const AppManagementRejectedChangesRestored()),
      slivers: (BuildContext context, AppsPolicy policy) {
        return <Widget>[
          BlocBuilder<AppInventoryBloc, AppInventoryState>(
            builder: (BuildContext context, AppInventoryState inventory) {
              return switch (inventory) {
                AppInventoryLoading() => const SliverToBoxAdapter(
                  child: SkeletonListGroup(rows: 6),
                ),
                AppInventoryError(:final failure) => SliverToBoxAdapter(
                  child: AppPanel(
                    child: ErrorState.fromError(
                      failure,
                      subject: 'os apps do aparelho',
                      compact: true,
                      onRetry: () {
                        context.read<AppInventoryBloc>().add(const AppInventoryRetryRequested());
                      },
                    ),
                  ),
                ),
                AppInventoryLoaded() => _AppsSliver(
                  policy: policy,
                  inventory: inventory,
                  search: _search,
                  onOpenApp: (AppEntry app) => _openApp(policy, app),
                  onOpenNewApps: () => _openNewApps(policy, inventory.inventory.apps),
                  onApplyToAll: _applyToAll,
                  onClearFilters: _clearFilters,
                ),
              };
            },
          ),
        ];
      },
    );
  }
}

/// Filtros, aviso de apps novos e a lista de apps (construida sob demanda).
class _AppsSliver extends StatelessWidget {
  const _AppsSliver({
    required this.policy,
    required this.inventory,
    required this.search,
    required this.onOpenApp,
    required this.onOpenNewApps,
    required this.onApplyToAll,
    required this.onClearFilters,
  });

  final AppsPolicy policy;
  final AppInventoryLoaded inventory;
  final TextEditingController search;
  final ValueChanged<AppEntry> onOpenApp;
  final VoidCallback onOpenNewApps;
  final Future<void> Function(List<AppEntry> listed, AppRuleState state) onApplyToAll;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final AppInventoryBloc list = context.read<AppInventoryBloc>();
    final AppListFilter filter = inventory.filter;
    final List<AppEntry> apps = inventory.inventory.apps;
    final List<AppEntry> visible = visibleApps(apps, policy, filter);
    final List<AppEntry> anyState = visibleApps(
      apps,
      policy,
      filter.copyWith(state: AppStateFilter.all),
    );
    int countOf(AppStateFilter option) {
      return anyState.where((AppEntry app) => option.matches(effectiveStateOf(policy, app))).length;
    }

    final bool blockNew = policy.defaultForNewApps == NewAppDefault.blocked;
    final int pending = visibleApps(apps, policy, const AppListFilter())
        .where((AppEntry app) => effectiveStateOf(policy, app) == EffectiveAppState.pendingApproval)
        .length;
    final Set<AppCategory> categories = categoriesOf(apps);
    final bool canApply = filter.isNarrowed && visible.any((AppEntry app) => !app.essential);

    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (pending > 0) ...<Widget>[
                AppBanner(
                  tone: Tone.warning,
                  icon: AppIcons.newApp,
                  title: pending == 1
                      ? '1 app novo aguarda sua decisão'
                      : '$pending apps novos aguardam sua decisão',
                  message: 'Eles ficam bloqueados até você escolher se podem ser usados.',
                  actionLabel: 'Ver apps novos',
                  onAction: () => list.add(const AppListStateFilterChanged(AppStateFilter.pending)),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppListGroup(
                children: <Widget>[
                  AppListRow(
                    leading: AppIconTile(
                      icon: AppIcons.install,
                      tone: blockNew ? Tone.warning : Tone.info,
                    ),
                    title: 'Apps instalados depois',
                    subtitle: blockNew
                        ? 'Ficam bloqueados até você aprovar'
                        : 'Podem ser usados assim que instalados',
                    onTap: onOpenNewApps,
                  ),
                ],
              ),
              const SectionGap(),
              AppTextField(
                controller: search,
                label: 'Buscar app',
                hint: 'Nome do app',
                prefixIcon: AppIcons.search,
                textInputAction: TextInputAction.search,
                onChanged: (String value) => list.add(AppListQueryChanged(value)),
                suffix: filter.query.isEmpty
                    ? null
                    : AppIconButton(
                        icon: AppIcons.close,
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          search.clear();
                          list.add(const AppListQueryChanged(''));
                        },
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppChoiceChips<AppStateFilter>(
                choices: <AppChoice<AppStateFilter>>[
                  for (final AppStateFilter option in AppStateFilter.values)
                    if (option != AppStateFilter.pending || blockNew)
                      AppChoice<AppStateFilter>(
                        value: option,
                        label: '${option.label} (${countOf(option)})',
                      ),
                ],
                selected: filter.state,
                onSelected: (AppStateFilter value) => list.add(AppListStateFilterChanged(value)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  MenuAnchor(
                    menuChildren: <Widget>[
                      MenuItemButton(
                        onPressed: () => list.add(const AppListCategoryChanged(null)),
                        child: const Text('Todas as categorias'),
                      ),
                      for (final AppCategory category in AppCategory.values)
                        if (categories.contains(category))
                          MenuItemButton(
                            onPressed: () => list.add(AppListCategoryChanged(category)),
                            child: Text(category.label),
                          ),
                    ],
                    builder: (BuildContext context, MenuController menu, Widget? child) {
                      return AppButton.tertiary(
                        label: filter.category?.label ?? 'Todas as categorias',
                        icon: AppIcons.filter,
                        size: AppButtonSize.compact,
                        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                      );
                    },
                  ),
                  if (canApply)
                    MenuAnchor(
                      menuChildren: <Widget>[
                        MenuItemButton(
                          leadingIcon: const Icon(AppIcons.check),
                          onPressed: () => onApplyToAll(visible, AppRuleState.allowed),
                          child: const Text('Permitir todos da lista'),
                        ),
                        MenuItemButton(
                          leadingIcon: const Icon(AppIcons.blocked),
                          onPressed: () => onApplyToAll(visible, AppRuleState.blocked),
                          child: const Text('Bloquear todos da lista'),
                        ),
                        MenuItemButton(
                          leadingIcon: const Icon(AppIcons.exception),
                          onPressed: () => onApplyToAll(visible, AppRuleState.exception),
                          child: const Text('Tornar todos exceção'),
                        ),
                      ],
                      builder: (BuildContext context, MenuController menu, Widget? child) {
                        return AppButton.tertiary(
                          label: 'Aplicar a todos',
                          icon: AppIcons.checkAll,
                          size: AppButtonSize.compact,
                          onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                        );
                      },
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.sm,
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    visible.length == 1 ? '1 app' : '${visible.length} apps',
                    style: context.text.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (visible.isEmpty)
          SliverToBoxAdapter(
            child: AppPanel(
              child: EmptyState(
                compact: true,
                icon: AppIcons.search,
                title: 'Nenhum app encontrado',
                message:
                    'Nenhum app combina com a busca e os filtros. A lista vem do aparelho da '
                    'criança e é atualizada a cada sincronização.',
                actionLabel: filter.isNarrowed ? 'Limpar filtros' : null,
                onAction: filter.isNarrowed ? onClearFilters : null,
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (BuildContext context, int index) {
              final AppEntry app = visible[index];
              return _GroupedRow(
                first: index == 0,
                last: index == visible.length - 1,
                child: _AppRow(
                  app: app,
                  rule: policy.rules[app.package],
                  state: effectiveStateOf(policy, app),
                  onTap: () => onOpenApp(app),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Uma linha de lista agrupada construida sob demanda: o mesmo visual do [AppListGroup] (um
/// unico painel, divisores recuados), sem montar todas as linhas de uma vez.
class _GroupedRow extends StatelessWidget {
  const _GroupedRow({required this.first, required this.last, required this.child});

  final bool first;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Radius radius = Radius.circular(context.shapes.container);
    return Material(
      color: context.colors.surface,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.vertical(
        top: first ? radius : Radius.zero,
        bottom: last ? radius : Radius.zero,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!first)
            const Divider(
              height: AppSizes.hairline,
              indent: AppSpacing.lg + AppSizes.iconTile + AppSpacing.md,
            ),
          child,
        ],
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.rule, required this.state, required this.onTap});

  final AppEntry app;
  final AppRule? rule;
  final EffectiveAppState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int? limit = rule?.dailyLimitMinutes;
    final String details = <String>[
      app.category.label,
      'hoje ${formatDurationMs(app.todayMs)}',
      if (limit != null) 'limite ${formatMinutes(limit)} por dia',
      if (app.removed) 'removido do aparelho',
    ].join(' · ');
    final Widget badge = StatusBadge(label: state.label, tone: state.tone, icon: state.icon);
    // Com fonte grande a etiqueta vai para baixo do nome, para nada ser cortado.
    final bool roomy = MediaQuery.textScalerOf(context).scale(AppSpacing.lg) <= AppSpacing.xl;
    return AppListRow(
      key: ValueKey<String>('app-${app.package}'),
      leading: AppIconView.forApp(app, size: AppSizes.iconTile),
      title: app.label,
      subtitle: details,
      trailing: roomy ? badge : null,
      below: roomy ? null : Align(alignment: AlignmentDirectional.centerStart, child: badge),
      showChevron: false,
      onTap: onTap,
    );
  }
}
