import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_paths.dart';
import '../app_management/presentation/services/installed_app_icons.dart';
import '../device_linking/device_linking_child_routes.dart';
import '../device_linking/domain/entities/link_state.dart';
import '../device_linking/presentation/bloc/child_link/child_link_bloc.dart';
import '../screen_time/presentation/bloc/time_request_sheet/time_request_sheet_bloc.dart';
import 'presentation/bloc/child_device_status/child_device_status_bloc.dart';
import 'presentation/bloc/child_home/child_home_bloc.dart';
import 'presentation/bloc/child_shell/child_shell_bloc.dart';
import 'presentation/bloc/guardian_area/guardian_area_bloc.dart';
import 'presentation/bloc/permissions/permissions_bloc.dart';
import 'presentation/pages/child_entry_page.dart';
import 'presentation/pages/child_home_page.dart';
import 'presentation/pages/guardian_area_page.dart';
import 'presentation/pages/permissions_page.dart';
import 'presentation/pages/transparency_page.dart';
import 'presentation/services/foreground_tracker.dart';
import 'presentation/shell/child_shell.dart';

/// Area inteira do modo crianca (todos os caminhos sob [ChildPaths.root]), dentro do
/// [ChildShell].
///
/// A casca entrega a todas as telas da area: o [ChildLinkBloc] (o mesmo do roteador), o
/// [ChildShellBloc] (acoes de abertura), o [ChildDeviceStatusBloc] (retrato do agente,
/// consultado a cada segundo com o aparelho vinculado e o app em primeiro plano), o
/// [ForegroundTracker] e os icones dos apps ([InstalledAppIcons]). Os BLoCs de cada tela sao
/// criados na rota da tela.
ShellRoute childShellRoute(GetIt di) {
  return ShellRoute(
    builder: (BuildContext context, GoRouterState state, Widget child) {
      return MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<ForegroundTracker>.value(value: di<ForegroundTracker>()),
          RepositoryProvider<InstalledAppIcons>.value(value: di<InstalledAppIcons>()),
        ],
        child: MultiBlocProvider(
          providers: <BlocProvider<Object?>>[
            BlocProvider<ChildLinkBloc>.value(value: di<ChildLinkBloc>()),
            BlocProvider<ChildShellBloc>(
              create: (BuildContext context) =>
                  di<ChildShellBloc>()..add(const ChildShellStarted()),
            ),
            BlocProvider<ChildDeviceStatusBloc>(
              lazy: false,
              create: (BuildContext context) {
                return di<ChildDeviceStatusBloc>()..add(const ChildDeviceStatusStarted());
              },
            ),
          ],
          child: ChildShell(location: state.uri.path, child: child),
        ),
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: ChildPaths.root,
        builder: (BuildContext context, GoRouterState state) => const ChildEntryPage(),
      ),
      childLinkRoute(di),
      GoRoute(
        path: ChildPaths.setupTransparency,
        builder: (BuildContext context, GoRouterState state) {
          return const TransparencyPage(setup: true);
        },
      ),
      GoRoute(
        path: ChildPaths.setupPermissions,
        builder: (BuildContext context, GoRouterState state) => _permissions(di, setup: true),
      ),
      GoRoute(
        path: ChildPaths.home,
        builder: (BuildContext context, GoRouterState state) {
          return MultiBlocProvider(
            providers: <BlocProvider<Object?>>[
              BlocProvider<ChildHomeBloc>(
                create: (BuildContext context) =>
                    di<ChildHomeBloc>()..add(const ChildHomeStarted()),
              ),
              BlocProvider<TimeRequestSheetBloc>(
                create: (BuildContext context) => di<TimeRequestSheetBloc>(),
              ),
            ],
            child: const ChildHomePage(),
          );
        },
      ),
      GoRoute(
        path: ChildPaths.about,
        builder: (BuildContext context, GoRouterState state) {
          return const TransparencyPage(setup: false);
        },
      ),
      GoRoute(
        path: ChildPaths.permissions,
        builder: (BuildContext context, GoRouterState state) => _permissions(di, setup: false),
      ),
      GoRoute(
        path: ChildPaths.guardianArea,
        builder: (BuildContext context, GoRouterState state) {
          return BlocProvider<GuardianAreaBloc>(
            create: (BuildContext context) => di<GuardianAreaBloc>(),
            child: const GuardianAreaPage(),
          );
        },
      ),
    ],
  );
}

Widget _permissions(GetIt di, {required bool setup}) {
  return BlocProvider<PermissionsBloc>(
    create: (BuildContext context) => di<PermissionsBloc>()..add(const PermissionsLoadRequested()),
    child: PermissionsPage(setup: setup),
  );
}

/// Redirecionamento dentro da area da crianca. O roteador do app chama so quando o modo e
/// crianca e o destino ja esta sob [ChildPaths.root], com a fase atual do [ChildLinkBloc].
///
/// Sem vinculo so existe a tela do codigo. Logo depois de vincular, so a configuracao inicial
/// (transparencia e permissoes). Vinculado e configurado, a tela inicial e as demais.
String? childRedirect(LinkPhase phase, String location) {
  switch (phase) {
    case LinkPhase.unknown:
    case LinkPhase.failed:
      return location == ChildPaths.root ? null : ChildPaths.root;
    case LinkPhase.unlinked:
      return location == ChildPaths.link ? null : ChildPaths.link;
    case LinkPhase.onboarding:
      return location.startsWith(ChildPaths.setupPrefix) ? null : ChildPaths.setupTransparency;
    case LinkPhase.ready:
      final bool entryOnly =
          location == ChildPaths.root ||
          location == ChildPaths.link ||
          location.startsWith(ChildPaths.setupPrefix);
      return entryOnly ? ChildPaths.home : null;
  }
}
