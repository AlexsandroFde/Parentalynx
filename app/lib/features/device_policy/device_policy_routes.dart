import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_paths.dart';
import '../child_device/domain/entities/child_device.dart';
import 'presentation/bloc/policy_overview/policy_overview_bloc.dart';
import 'presentation/overview/rule_group.dart';
import 'presentation/pages/rules_overview_page.dart';

/// Raiz da aba "Regras" (`GuardianPaths.rules`): a visao geral com os [groups] e, abaixo dela,
/// as paginas de edicao de cada funcionalidade de regras ([routes], com caminhos relativos).
///
/// Os grupos e as rotas vem das funcionalidades de regras e sao montados pela composicao do
/// app, para que a politica nao dependa delas.
GoRoute rulesOverviewRoute(
  GetIt di, {
  required List<RuleGroup> groups,
  required List<RouteBase> routes,
}) {
  return GoRoute(
    path: GuardianPaths.rules,
    builder: (BuildContext context, GoRouterState state) {
      return RulesOverviewGate(
        bodyBuilder: (BuildContext context, ChildDevice device) {
          return BlocProvider<PolicyOverviewBloc>(
            key: ValueKey<String>('rules-overview-${device.id}'),
            create: (BuildContext context) {
              return di<PolicyOverviewBloc>()..add(PolicyOverviewStarted(device.id));
            },
            child: RulesOverviewBody(device: device, groups: groups),
          );
        },
      );
    },
    routes: routes,
  );
}
