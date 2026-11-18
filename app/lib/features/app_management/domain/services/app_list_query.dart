import '../../../device_policy/domain/entities/policy.dart';
import '../entities/app_entry.dart';
import '../entities/app_list_filter.dart';
import 'app_rules_editing.dart';

/// Consultas puras sobre o inventario de apps e as regras.

/// Apps que aparecem na lista de regras com o filtro informado: os voltados ao usuario ou com
/// regra gravada (removidos so quando tem regra), em ordem alfabetica, essenciais no fim.
List<AppEntry> visibleApps(List<AppEntry> apps, AppsPolicy policy, AppListFilter filter) {
  final String query = filter.query.trim().toLowerCase();
  final List<AppEntry> result = apps.where((AppEntry app) {
    final bool hasRule = policy.rules.containsKey(app.package);
    final bool listed = app.isUserFacing || hasRule;
    if (!listed || (app.removed && !hasRule)) {
      return false;
    }
    final AppCategory? category = filter.category;
    if (category != null && app.category != category) {
      return false;
    }
    if (query.isNotEmpty &&
        !app.label.toLowerCase().contains(query) &&
        !app.package.toLowerCase().contains(query)) {
      return false;
    }
    return filter.state.matches(effectiveStateOf(policy, app));
  }).toList();
  result.sort((AppEntry a, AppEntry b) {
    if (a.essential != b.essential) {
      return a.essential ? 1 : -1;
    }
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });
  return result;
}

/// Categorias que existem entre os apps voltados ao usuario, para o filtro por categoria.
Set<AppCategory> categoriesOf(List<AppEntry> apps) {
  return apps.where((AppEntry app) => app.isUserFacing).map((AppEntry app) => app.category).toSet();
}

/// Regras marcadas como excecao, na ordem em que estao na politica.
List<MapEntry<String, AppRule>> exceptionRules(AppsPolicy policy) {
  return policy.rules.entries
      .where((MapEntry<String, AppRule> entry) => entry.value.state == AppRuleState.exception)
      .toList();
}

/// Itens essenciais com icone no launcher, que nunca sao bloqueados.
List<AppEntry> essentialApps(List<AppEntry> apps) {
  return apps.where((AppEntry app) => app.essential && app.launchable).toList();
}
