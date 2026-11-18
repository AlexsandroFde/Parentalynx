import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../authentication/domain/entities/app_lock_timeout.dart';
import '../../../../authentication/domain/usecases/app_lock_preference.dart';

part 'security_settings_event.dart';
part 'security_settings_state.dart';

/// Bloqueio do painel: depois de quanto tempo em segundo plano a senha e pedida de novo.
class SecuritySettingsBloc extends Bloc<SecuritySettingsEvent, SecuritySettingsState> {
  SecuritySettingsBloc({required this._appLock}) : super(const SecuritySettingsState()) {
    on<SecuritySettingsStarted>(_onStarted, transformer: restartable());
    on<AppLockTimeoutSelected>(_onTimeoutSelected, transformer: sequential());
  }

  final AppLockPreference _appLock;

  Future<void> _onStarted(
    SecuritySettingsStarted event,
    Emitter<SecuritySettingsState> emit,
  ) async {
    emit(SecuritySettingsState(timeout: await _appLock.read()));
  }

  Future<void> _onTimeoutSelected(
    AppLockTimeoutSelected event,
    Emitter<SecuritySettingsState> emit,
  ) async {
    // A escolha aparece na hora; a gravacao local nao falha de forma que a pessoa precise ver.
    emit(SecuritySettingsState(timeout: event.timeout));
    await _appLock.write(event.timeout);
  }
}
