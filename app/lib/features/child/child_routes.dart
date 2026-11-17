import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'agent/presentation/child_session.dart';
import 'child_paths.dart';
import 'guardian_area/presentation/guardian_area_page.dart';
import 'home/presentation/child_home_page.dart';
import 'linking/presentation/link_page.dart';
import 'permissions/presentation/permissions_page.dart';
import 'shell/child_shell.dart';
import 'transparency/presentation/transparency_page.dart';

export 'child_paths.dart';

/// Rotas do modo crianca. Todas ficam dentro do [ChildShell], que cuida do que vale para a
/// area inteira (servico do agente, segundo plano, acoes de abertura).
final List<RouteBase> childRoutes = <RouteBase>[
  ShellRoute(
    builder: (BuildContext context, GoRouterState state, Widget child) {
      return ChildShell(location: state.uri.path, child: child);
    },
    routes: <RouteBase>[
      GoRoute(
        path: ChildPaths.root,
        builder: (BuildContext context, GoRouterState state) => const ChildEntryPage(),
      ),
      GoRoute(
        path: ChildPaths.link,
        builder: (BuildContext context, GoRouterState state) => const LinkPage(),
      ),
      GoRoute(
        path: ChildPaths.setupTransparency,
        builder: (BuildContext context, GoRouterState state) {
          return const TransparencyPage(setup: true);
        },
      ),
      GoRoute(
        path: ChildPaths.setupPermissions,
        builder: (BuildContext context, GoRouterState state) {
          return const PermissionsPage(setup: true);
        },
      ),
      GoRoute(
        path: ChildPaths.home,
        builder: (BuildContext context, GoRouterState state) => const ChildHomePage(),
      ),
      GoRoute(
        path: ChildPaths.about,
        builder: (BuildContext context, GoRouterState state) {
          return const TransparencyPage(setup: false);
        },
      ),
      GoRoute(
        path: ChildPaths.permissions,
        builder: (BuildContext context, GoRouterState state) {
          return const PermissionsPage(setup: false);
        },
      ),
      GoRoute(
        path: ChildPaths.guardianArea,
        builder: (BuildContext context, GoRouterState state) => const GuardianAreaPage(),
      ),
    ],
  ),
];

/// Redirecionamento dentro da area da crianca. Chamado pelo roteador so quando o modo e
/// crianca e o destino ja esta sob [ChildPaths.root].
///
/// Sem vinculo so existe a tela do codigo. Logo depois de vincular, so a configuracao inicial
/// (transparencia e permissoes). Vinculado e configurado, a tela inicial e as demais.
String? childRedirect(Ref ref, GoRouterState state) {
  final String location = state.matchedLocation;
  switch (ref.read(childLinkProvider)) {
    case ChildLinkPhase.unknown:
    case ChildLinkPhase.failed:
      return location == ChildPaths.root ? null : ChildPaths.root;
    case ChildLinkPhase.unlinked:
      return location == ChildPaths.link ? null : ChildPaths.link;
    case ChildLinkPhase.onboarding:
      return location.startsWith(ChildPaths.setupPrefix) ? null : ChildPaths.setupTransparency;
    case ChildLinkPhase.ready:
      final bool entryOnly =
          location == ChildPaths.root ||
          location == ChildPaths.link ||
          location.startsWith(ChildPaths.setupPrefix);
      return entryOnly ? ChildPaths.home : null;
  }
}

/// Registra o que deve fazer o roteador reavaliar os redirecionamentos desta area.
void registerChildRouterRefresh(Ref ref, void Function() refresh) {
  ref.listen<ChildLinkPhase>(
    childLinkProvider,
    (ChildLinkPhase? previous, ChildLinkPhase next) => refresh(),
  );
}
