import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../child_device/domain/entities/child_device.dart';
import '../device_policy/presentation/widgets/selected_device_gate.dart';
import 'domain/entities/app_entry.dart';
import 'presentation/bloc/app_inventory/app_inventory_bloc.dart';
import 'presentation/bloc/app_management/app_management_bloc.dart';
import 'presentation/pages/apps_rules_page.dart';
import 'presentation/pages/exceptions_page.dart';

/// Paginas de regras de aplicativos abaixo da aba Regras. Caminhos relativos a
/// `GuardianPaths.rules`. A lista de apps aceita `?category=<codigo>` para abrir filtrada.
List<RouteBase> appManagementRuleRoutes(GetIt di) {
  Widget withBlocs(ChildDevice device, String key, Widget page, {AppCategory? category}) {
    return MultiBlocProvider(
      key: ValueKey<String>('$key-${device.id}'),
      providers: <BlocProvider<Object?>>[
        BlocProvider<AppManagementBloc>(
          create: (BuildContext context) =>
              di<AppManagementBloc>()..add(AppManagementStarted(device.id)),
        ),
        BlocProvider<AppInventoryBloc>(
          create: (BuildContext context) =>
              di<AppInventoryBloc>()
                ..add(AppInventoryStarted(deviceId: device.id, initialCategory: category)),
        ),
      ],
      child: page,
    );
  }

  return <RouteBase>[
    GoRoute(
      path: 'apps',
      builder: (BuildContext context, GoRouterState state) {
        final String? category = state.uri.queryParameters['category'];
        return SelectedDeviceGate(
          title: 'Aplicativos',
          builder: (BuildContext context, ChildDevice device) {
            return withBlocs(
              device,
              'apps-rules',
              AppsRulesPage(device: device),
              category: category == null ? null : AppCategory.parse(category),
            );
          },
        );
      },
    ),
    GoRoute(
      path: 'exceptions',
      builder: (BuildContext context, GoRouterState state) {
        return SelectedDeviceGate(
          title: 'Exceções e funções essenciais',
          builder: (BuildContext context, ChildDevice device) {
            return withBlocs(device, 'exceptions', ExceptionsPage(device: device));
          },
        );
      },
    ),
  ];
}
