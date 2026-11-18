import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/action_status.dart';
import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../blocking/domain/usecases/clear_local_override.dart';
import '../../../../blocking/domain/usecases/grant_local_override.dart';
import '../../../../device_linking/domain/usecases/unlink_this_device.dart';
import '../../../domain/entities/admin_auth.dart';
import '../../../domain/usecases/disable_device_admin.dart';
import '../../../domain/usecases/enable_device_admin.dart';
import '../../../domain/usecases/release_device_ownership.dart';
import '../../../domain/usecases/verify_guardian_password.dart';
import '../../../domain/usecases/verify_offline_access_code.dart';
import '../../texts/admin_auth_texts.dart';

part 'guardian_area_event.dart';
part 'guardian_area_state.dart';

/// Area do responsavel no aparelho da crianca: autenticacao e operacoes administrativas.
///
/// Cada visita a area exige uma nova autenticacao, mesmo que a anterior ainda valha no lado
/// nativo: assim, depois que o responsavel sai, ninguem entra de novo sem a senha. Quando o
/// agente recusa uma operacao porque a autenticacao venceu, a area volta a pedir a senha.
class GuardianAreaBloc extends Bloc<GuardianAreaEvent, GuardianAreaState> {
  GuardianAreaBloc({
    required this._verifyGuardianPassword,
    required this._verifyOfflineAccessCode,
    required this._grantLocalOverride,
    required this._clearLocalOverride,
    required this._enableDeviceAdmin,
    required this._disableDeviceAdmin,
    required this._releaseDeviceOwnership,
    required this._unlinkThisDevice,
  }) : super(const GuardianAreaLocked()) {
    on<GuardianAreaModeToggled>(_onModeToggled);
    on<GuardianAreaPasswordSubmitted>(_onPasswordSubmitted, transformer: droppable());
    on<GuardianAreaCodeSubmitted>(_onCodeSubmitted, transformer: droppable());
    on<GuardianAreaLeft>(_onLeft);
    on<GuardianAreaOverrideGranted>(_onOverrideGranted, transformer: droppable());
    on<GuardianAreaOverrideCleared>(_onOverrideCleared, transformer: droppable());
    on<GuardianAreaDeviceAdminRequested>(_onDeviceAdminRequested, transformer: droppable());
    on<GuardianAreaDeviceAdminRemoved>(_onDeviceAdminRemoved, transformer: droppable());
    on<GuardianAreaOwnershipReleased>(_onOwnershipReleased, transformer: droppable());
    on<GuardianAreaUnlinkRequested>(_onUnlinkRequested, transformer: droppable());
  }

  final VerifyGuardianPassword _verifyGuardianPassword;
  final VerifyOfflineAccessCode _verifyOfflineAccessCode;
  final GrantLocalOverride _grantLocalOverride;
  final ClearLocalOverride _clearLocalOverride;
  final EnableDeviceAdmin _enableDeviceAdmin;
  final DisableDeviceAdmin _disableDeviceAdmin;
  final ReleaseDeviceOwnership _releaseDeviceOwnership;
  final UnlinkThisDevice _unlinkThisDevice;

  /// Senha usada nesta visita. Fica so em memoria e serve para o servidor revogar o vinculo.
  String? _password;

  void _onModeToggled(GuardianAreaModeToggled event, Emitter<GuardianAreaState> emit) {
    final GuardianAreaState current = state;
    if (current is GuardianAreaLocked && !current.verifying) {
      emit(GuardianAreaLocked(codeMode: !current.codeMode));
    }
  }

  Future<void> _onPasswordSubmitted(
    GuardianAreaPasswordSubmitted event,
    Emitter<GuardianAreaState> emit,
  ) async {
    final GuardianAreaState current = state;
    if (current is! GuardianAreaLocked || current.verifying) {
      return;
    }
    emit(const GuardianAreaLocked(verifying: true));
    final Result<AdminAuth> result = await _verifyGuardianPassword(event.password);
    switch (result) {
      case Ok<AdminAuth>(value: final AdminAuth auth) when auth.isGranted:
        _password = event.password;
        emit(const GuardianAreaUnlocked());
      case Ok<AdminAuth>(value: final AdminAuth auth):
        emit(
          GuardianAreaLocked(
            // Sem conexao a senha nao pode ser conferida: oferece o codigo offline.
            codeMode: auth.status == AdminAuthStatus.offline,
            error: adminAuthMessage(auth, viaCode: false),
          ),
        );
      case Err<AdminAuth>(:final AppFailure failure):
        emit(GuardianAreaLocked(error: failure.message));
    }
  }

  Future<void> _onCodeSubmitted(
    GuardianAreaCodeSubmitted event,
    Emitter<GuardianAreaState> emit,
  ) async {
    final GuardianAreaState current = state;
    if (current is! GuardianAreaLocked || current.verifying) {
      return;
    }
    emit(const GuardianAreaLocked(codeMode: true, verifying: true));
    final Result<AdminAuth> result = await _verifyOfflineAccessCode(event.code);
    switch (result) {
      case Ok<AdminAuth>(value: final AdminAuth auth) when auth.isGranted:
        // Sem a senha, desvincular fica so local: o servidor e avisado depois.
        _password = null;
        emit(const GuardianAreaUnlocked(codeMode: true));
      case Ok<AdminAuth>(value: final AdminAuth auth):
        emit(GuardianAreaLocked(codeMode: true, error: adminAuthMessage(auth, viaCode: true)));
      case Err<AdminAuth>(:final AppFailure failure):
        emit(GuardianAreaLocked(codeMode: true, error: failure.message));
    }
  }

  void _onLeft(GuardianAreaLeft event, Emitter<GuardianAreaState> emit) {
    _password = null;
    emit(GuardianAreaLocked(codeMode: state.codeMode));
  }

  Future<void> _onOverrideGranted(
    GuardianAreaOverrideGranted event,
    Emitter<GuardianAreaState> emit,
  ) {
    return _run(
      emit,
      GuardianOperation.grantOverride,
      () => _grantLocalOverride(event.minutes),
      success: overrideGrantedMessage(event.minutes),
    );
  }

  Future<void> _onOverrideCleared(
    GuardianAreaOverrideCleared event,
    Emitter<GuardianAreaState> emit,
  ) {
    return _run(
      emit,
      GuardianOperation.clearOverride,
      _clearLocalOverride.call,
      success: overrideClearedMessage,
    );
  }

  Future<void> _onDeviceAdminRequested(
    GuardianAreaDeviceAdminRequested event,
    Emitter<GuardianAreaState> emit,
  ) {
    return _run(emit, GuardianOperation.requestDeviceAdmin, _enableDeviceAdmin.call);
  }

  Future<void> _onDeviceAdminRemoved(
    GuardianAreaDeviceAdminRemoved event,
    Emitter<GuardianAreaState> emit,
  ) {
    return _run(
      emit,
      GuardianOperation.removeDeviceAdmin,
      _disableDeviceAdmin.call,
      success: deviceAdminRemovedMessage,
    );
  }

  Future<void> _onOwnershipReleased(
    GuardianAreaOwnershipReleased event,
    Emitter<GuardianAreaState> emit,
  ) {
    return _run(
      emit,
      GuardianOperation.releaseOwnership,
      _releaseDeviceOwnership.call,
      success: ownershipReleasedMessage,
    );
  }

  Future<void> _onUnlinkRequested(
    GuardianAreaUnlinkRequested event,
    Emitter<GuardianAreaState> emit,
  ) {
    return _run(emit, GuardianOperation.unlink, () async {
      final Result<bool> unlinked = await _unlinkThisDevice(password: _password);
      return switch (unlinked) {
        // O aparelho ficou sem vinculo: o roteador sai da area do responsavel.
        Ok<bool>(value: true) => okVoid,
        Ok<bool>() => const Err<void>(UnexpectedFailure(unlinkFailedMessage)),
        Err<bool>(:final AppFailure failure) => Err<void>(failure),
      };
    });
  }

  /// Executa uma operacao administrativa mostrando o andamento e o resultado.
  ///
  /// Se o agente recusar porque a autenticacao do responsavel venceu, volta a pedir a senha.
  Future<void> _run(
    Emitter<GuardianAreaState> emit,
    GuardianOperation operation,
    Future<Result<void>> Function() command, {
    String? success,
  }) async {
    final GuardianAreaState current = state;
    if (current is! GuardianAreaUnlocked || current.isBusy) {
      return;
    }
    emit(GuardianAreaUnlocked(codeMode: current.codeMode, running: operation));
    final Result<void> result = await command();
    final GuardianAreaState now = state;
    if (now is! GuardianAreaUnlocked) {
      return;
    }
    switch (result) {
      case Ok<void>():
        if (operation == GuardianOperation.unlink) {
          _password = null;
        }
        emit(
          GuardianAreaUnlocked(
            codeMode: now.codeMode,
            action: ActionSucceeded(message: success),
          ),
        );
      case Err<void>(failure: final NativeFailure failure) when failure.isAdminAuthRequired:
        _password = null;
        emit(GuardianAreaLocked(codeMode: now.codeMode, error: adminAccessExpiredMessage));
      case Err<void>(:final AppFailure failure):
        emit(GuardianAreaUnlocked(codeMode: now.codeMode, action: actionStatusForFailure(failure)));
    }
  }

  @override
  Future<void> close() {
    _password = null;
    return super.close();
  }
}
