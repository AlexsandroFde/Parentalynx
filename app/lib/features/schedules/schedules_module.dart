import 'package:get_it/get_it.dart';

import '../device_policy/device_policy_module.dart';
import 'domain/entities/schedule_section.dart';
import 'presentation/bloc/schedule/schedule_bloc.dart';

/// Registra as dependencias de horarios: horarios permitidos e periodos de bloqueio.
void registerSchedulesModule(GetIt di) {
  // Uma instancia por tela aberta.
  di.registerFactory<ScheduleBloc>(
    () => ScheduleBloc(editor: createPolicySectionEditor(di, const ScheduleSection())),
  );
}
