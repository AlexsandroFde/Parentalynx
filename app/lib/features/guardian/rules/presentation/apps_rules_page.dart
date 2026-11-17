import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'app_rule_sheet.dart';
import 'widgets/policy_sync_status.dart';
import 'widgets/rule_scaffold.dart';

enum _StateFilter {
  all('Todos'),
  allowed('Permitidos'),
  blocked('Bloqueados'),
  exception('Exceções'),
  pending('Aguardando');

  const _StateFilter(this.label);

  final String label;

  bool matches(EffectiveAppState state) {
    return switch (this) {
      _StateFilter.all => true,
      _StateFilter.allowed => state == EffectiveAppState.allowed,
      _StateFilter.blocked => state == EffectiveAppState.blocked,
      _StateFilter.exception => state == EffectiveAppState.exception,
      _StateFilter.pending => state == EffectiveAppState.pendingApproval,
    };
  }
}

/// Lista dos apps instalados no aparelho, com o estado de cada um e a edicao por app.
class AppsRulesPage extends ConsumerStatefulWidget {
  const AppsRulesPage({this.initialCategory, super.key});

  /// Categoria ja selecionada ao abrir (por exemplo navegadores).
  final AppCategory? initialCategory;

  @override
  ConsumerState<AppsRulesPage> createState() => _AppsRulesPageState();
}

class _AppsRulesPageState extends ConsumerState<AppsRulesPage> {
  final TextEditingController _search = TextEditingController();
  _StateFilter _filter = _StateFilter.all;
  late AppCategory? _category = widget.initialCategory;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static KnownApp _known(AppEntry app) {
    return (package: app.package, system: app.system, essential: app.essential);
  }

  List<AppEntry> _visible(List<AppEntry> apps, AppsPolicy policy) {
    final String query = _search.text.trim().toLowerCase();
    final List<AppEntry> result = apps.where((AppEntry app) {
      final bool listed = app.isUserFacing || policy.rules.containsKey(app.package);
      if (!listed || (app.removed && !policy.rules.containsKey(app.package))) {
        return false;
      }
      if (_category != null && app.category != _category) {
        return false;
      }
      if (query.isNotEmpty &&
          !app.label.toLowerCase().contains(query) &&
          !app.package.toLowerCase().contains(query)) {
        return false;
      }
      return _filter.matches(
        effectiveAppState(
          policy,
          package: app.package,
          system: app.system,
          essential: app.essential,
        ),
      );
    }).toList();
    result.sort((AppEntry a, AppEntry b) {
      if (a.essential != b.essential) {
        return a.essential ? 1 : -1;
      }
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return result;
  }

  Future<void> _openApp(RuleEditing editing, AppEntry app) async {
    final AppsPolicy policy = editing.draft.apps;
    final AppRule? rule = await showAppRuleSheet(
      context,
      app: app,
      rule: policy.rules[app.package],
      state: effectiveAppState(
        policy,
        package: app.package,
        system: app.system,
        essential: app.essential,
      ),
    );
    if (rule != null) {
      editing.update(
        (Policy p) => p.copyWith(apps: setAppRule(p.apps, app.package, rule, system: app.system)),
      );
    }
  }

  Future<void> _applyToAll(RuleEditing editing, List<AppEntry> listed, AppRuleState state) async {
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
      editing.update(
        (Policy p) => p.copyWith(apps: setStateForMany(p.apps, targets.map(_known), state)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RuleEditorScaffold(
      title: 'Aplicativos',
      body: (BuildContext context, RuleEditing editing) {
        final AsyncValue<DeviceApps> apps = ref.watch(deviceAppsProvider(editing.device.id));
        return AsyncValueView<DeviceApps>(
          value: apps,
          loadingMessage: 'Carregando os apps do aparelho',
          onRetry: () => ref.invalidate(deviceAppsProvider(editing.device.id)),
          data: (DeviceApps data) => _buildList(context, editing, data),
        );
      },
    );
  }

  Widget _buildList(BuildContext context, RuleEditing editing, DeviceApps data) {
    final ThemeData theme = Theme.of(context);
    final AppsPolicy policy = editing.draft.apps;
    final List<AppEntry> visible = _visible(data.apps, policy);
    final Set<AppCategory> categories = data.apps
        .where((AppEntry app) => app.isUserFacing)
        .map((AppEntry app) => app.category)
        .toSet();
    final bool narrowed =
        _filter != _StateFilter.all || _category != null || _search.text.trim().isNotEmpty;

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
                  PolicySyncStatus(device: editing.device),
                  const SizedBox(height: AppSpacing.md),
                  _NewAppsCard(
                    value: policy.defaultForNewApps,
                    onChanged: (NewAppDefault value) => editing.update(
                      (Policy p) => p.copyWith(
                        apps: setNewAppDefault(p.apps, value, knownApps: data.apps.map(_known)),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome ou pacote',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar busca',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(_search.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        for (final _StateFilter filter in _StateFilter.values)
                          if (filter != _StateFilter.pending ||
                              policy.defaultForNewApps == NewAppDefault.blocked)
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: ChoiceChip(
                                label: Text(filter.label),
                                selected: _filter == filter,
                                onSelected: (_) => setState(() => _filter = filter),
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
                            onSelected: (AppCategory? value) => setState(() => _category = value),
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
                                    _category?.label ?? 'Todas as categorias',
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
                          onSelected: (AppRuleState state) => _applyToAll(editing, visible, state),
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
                      state: effectiveAppState(
                        policy,
                        package: app.package,
                        system: app.system,
                        essential: app.essential,
                      ),
                      onTap: () => _openApp(editing, app),
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
