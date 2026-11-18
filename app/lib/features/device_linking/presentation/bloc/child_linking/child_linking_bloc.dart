import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../user_role/domain/entities/user_role.dart';
import '../../../../user_role/domain/usecases/change_user_role.dart';
import '../../../domain/entities/pairing_claim.dart';
import '../../../domain/entities/pairing_status.dart';
import '../../../domain/usecases/activate_linked_device.dart';
import '../../../domain/usecases/check_pairing_status.dart';
import '../../../domain/usecases/discard_pending_claim.dart';
import '../../../domain/usecases/get_device_identity.dart';
import '../../../domain/usecases/restore_pending_claim.dart';
import '../../../domain/usecases/submit_pairing_code.dart';
import '../../texts/child_linking_texts.dart';

part 'child_linking_event.dart';
part 'child_linking_state.dart';

/// Vinculacao deste aparelho: codigo, espera da aprovacao e ativacao do controle.
///
/// Enquanto espera, consulta o servidor a cada [pollInterval]. Ao ativar, o vinculo passa para
/// a configuracao inicial e o roteador sai desta tela: este BLoC nao precisa avisar ninguem.
class ChildLinkingBloc extends Bloc<ChildLinkingEvent, ChildLinkingState> {
  ChildLinkingBloc({
    required this._getDeviceIdentity,
    required this._submitPairingCode,
    required this._checkPairingStatus,
    required this._activateLinkedDevice,
    required this._restorePendingClaim,
    required this._discardPendingClaim,
    required this._changeUserRole,
    this.pollInterval = const Duration(seconds: 3),
  }) : super(const ChildLinkingForm(activity: LinkFormActivity.restoring)) {
    on<ChildLinkingStarted>(_onStarted, transformer: droppable());
    on<ChildLinkingCodeSubmitted>(_onCodeSubmitted, transformer: droppable());
    on<ChildLinkingPollRequested>(_onPollRequested, transformer: droppable());
    on<ChildLinkingWaitCancelled>(_onWaitCancelled, transformer: droppable());
    on<ChildLinkingErrorCleared>(_onErrorCleared);
    on<ChildLinkingLeaveRequested>(_onLeaveRequested, transformer: droppable());
  }

  final GetDeviceIdentity _getDeviceIdentity;
  final SubmitPairingCode _submitPairingCode;
  final CheckPairingStatus _checkPairingStatus;
  final ActivateLinkedDevice _activateLinkedDevice;
  final RestorePendingClaim _restorePendingClaim;
  final DiscardPendingClaim _discardPendingClaim;
  final ChangeUserRole _changeUserRole;

  /// Intervalo entre as consultas do andamento do pedido.
  final Duration pollInterval;

  Timer? _timer;
  String? _suggestedName;

  Future<void> _onStarted(ChildLinkingStarted event, Emitter<ChildLinkingState> emit) async {
    _suggestedName = (await _getDeviceIdentity()).valueOrNull?.name;
    final PairingClaim? claim = await _restorePendingClaim();
    final ChildLinkingState current = state;
    if (current is! ChildLinkingForm || current.activity != LinkFormActivity.restoring) {
      return;
    }
    if (claim == null) {
      emit(_form());
      return;
    }
    emit(ChildLinkingWaiting(claim: claim, suggestedDeviceName: _suggestedName));
    _startPolling();
    add(const ChildLinkingPollRequested());
  }

  Future<void> _onCodeSubmitted(
    ChildLinkingCodeSubmitted event,
    Emitter<ChildLinkingState> emit,
  ) async {
    final ChildLinkingState current = state;
    if (current is! ChildLinkingForm || current.activity != LinkFormActivity.idle) {
      return;
    }
    emit(_form(activity: LinkFormActivity.submitting));
    final Result<PairingClaim> result = await _submitPairingCode(
      code: event.code,
      deviceName: event.deviceName,
    );
    switch (result) {
      case Ok<PairingClaim>(:final PairingClaim value):
        emit(ChildLinkingWaiting(claim: value, suggestedDeviceName: _suggestedName));
        _startPolling();
      case Err<PairingClaim>(:final AppFailure failure):
        emit(_form(error: linkingErrorMessage(failure)));
    }
  }

  Future<void> _onPollRequested(
    ChildLinkingPollRequested event,
    Emitter<ChildLinkingState> emit,
  ) async {
    final ChildLinkingState current = state;
    if (current is! ChildLinkingWaiting) {
      return;
    }
    final PairingClaim claim = current.claim;
    final Result<PairingStatus> result = await _checkPairingStatus(claim);
    if (!_isStillWaitingFor(claim)) {
      return;
    }
    switch (result) {
      case Err<PairingStatus>():
        // Falha de rede ou do servidor: a espera continua e a tela avisa.
        emit(_waiting(claim, connectionTrouble: true));
      case Ok<PairingStatus>(value: PairingPending()):
        if (current.connectionTrouble) {
          emit(_waiting(claim));
        }
      case Ok<PairingStatus>(value: PairingRejected()):
        await _backToForm(emit, rejectedMessage);
      case Ok<PairingStatus>(value: PairingExpired()):
        await _backToForm(emit, expiredMessage);
      case Ok<PairingStatus>(value: final PairingApproved approved):
        await _activate(emit, claim, approved);
    }
  }

  Future<void> _onWaitCancelled(
    ChildLinkingWaitCancelled event,
    Emitter<ChildLinkingState> emit,
  ) async {
    _stopPolling();
    emit(_form());
    await _discardPendingClaim();
  }

  void _onErrorCleared(ChildLinkingErrorCleared event, Emitter<ChildLinkingState> emit) {
    final ChildLinkingState current = state;
    if (current is ChildLinkingForm &&
        current.error != null &&
        current.activity != LinkFormActivity.submitting) {
      emit(_form(activity: current.activity));
    }
  }

  Future<void> _onLeaveRequested(
    ChildLinkingLeaveRequested event,
    Emitter<ChildLinkingState> emit,
  ) async {
    final ChildLinkingState current = state;
    if (current is! ChildLinkingForm || current.activity.isBusy) {
      return;
    }
    emit(_form(activity: LinkFormActivity.leaving, error: current.error));
    final Result<void> result = await _changeUserRole(UserRole.unset);
    // Com sucesso o roteador leva para a escolha de modo.
    emit(_form(error: current.error, leaveFailure: result.failureOrNull));
  }

  bool _isStillWaitingFor(PairingClaim claim) {
    final ChildLinkingState now = state;
    return now is ChildLinkingWaiting && now.claim.linkId == claim.linkId;
  }

  Future<void> _backToForm(Emitter<ChildLinkingState> emit, String message) async {
    _stopPolling();
    emit(_form(error: message));
    await _discardPendingClaim();
  }

  Future<void> _activate(
    Emitter<ChildLinkingState> emit,
    PairingClaim claim,
    PairingApproved approved,
  ) async {
    _stopPolling();
    emit(ChildLinkingActivating(claim: claim, suggestedDeviceName: _suggestedName));
    final Result<void> result = await _activateLinkedDevice(claim, approved);
    if (result case Err<void>(:final AppFailure failure)) {
      emit(_form(error: activationFailedMessage(failure)));
    }
    // Com sucesso a fase do vinculo muda e o roteador segue para a configuracao inicial.
  }

  ChildLinkingForm _form({
    LinkFormActivity activity = LinkFormActivity.idle,
    String? error,
    AppFailure? leaveFailure,
  }) {
    return ChildLinkingForm(
      activity: activity,
      error: error,
      leaveFailure: leaveFailure,
      suggestedDeviceName: _suggestedName,
    );
  }

  ChildLinkingWaiting _waiting(PairingClaim claim, {bool connectionTrouble = false}) {
    return ChildLinkingWaiting(
      claim: claim,
      connectionTrouble: connectionTrouble,
      suggestedDeviceName: _suggestedName,
    );
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (Timer timer) => add(const ChildLinkingPollRequested()));
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }
}
