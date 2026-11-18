import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_paths.dart';
import 'presentation/bloc/child_linking/child_linking_bloc.dart';
import 'presentation/pages/link_page.dart';

/// Rota da tela do codigo (vinculacao) no aparelho da crianca. Fica dentro da area da
/// crianca, montada pelo `child_mode`.
GoRoute childLinkRoute(GetIt di) {
  return GoRoute(
    path: ChildPaths.link,
    builder: (BuildContext context, GoRouterState state) {
      return BlocProvider<ChildLinkingBloc>(
        create: (BuildContext context) => di<ChildLinkingBloc>()..add(const ChildLinkingStarted()),
        child: const LinkPage(),
      );
    },
  );
}
