import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/bloc/form_status.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../domain/entities/credential_errors.dart';
import '../../../domain/entities/guardian_session.dart';
import '../../../domain/services/credentials_policy.dart';
import '../../../domain/usecases/get_sign_in_defaults.dart';
import '../../../domain/usecases/register_guardian.dart';
import '../../messages/auth_messages.dart';

part 'register_event.dart';
part 'register_state.dart';

/// Formulario de criacao da conta do responsavel e da senha administrativa.
///
/// Ao criar a conta, a sessao abre com a chave de recuperacao pendente e o roteador leva a
/// tela da chave.
class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc({required this._register, required this._defaults}) : super(const RegisterState()) {
    on<RegisterStarted>(_onStarted, transformer: droppable());
    on<RegisterFieldEdited>(_onFieldEdited);
    on<RegisterSubmitted>(_onSubmitted, transformer: droppable());
  }

  final RegisterGuardian _register;
  final GetSignInDefaults _defaults;

  Future<void> _onStarted(RegisterStarted event, Emitter<RegisterState> emit) async {
    emit(state.copyWith(suggestedDeviceName: await _defaults.deviceName()));
  }

  void _onFieldEdited(RegisterFieldEdited event, Emitter<RegisterState> emit) {
    if (state.errors.of(event.field) != null) {
      emit(state.copyWith(errors: state.errors.without(event.field)));
    }
  }

  Future<void> _onSubmitted(RegisterSubmitted event, Emitter<RegisterState> emit) async {
    final CredentialErrors errors = CredentialsPolicy.validateRegistration(
      displayName: event.displayName,
      email: event.email,
      password: event.password,
      confirmation: event.confirmation,
    );
    if (!errors.isEmpty) {
      emit(state.copyWith(status: FormStatus.editing, errors: errors));
      return;
    }
    emit(state.copyWith(status: FormStatus.submitting, errors: CredentialErrors.none));
    final Result<AuthenticatedSession> result = await _register(
      email: event.email,
      displayName: event.displayName,
      password: event.password,
      deviceName: event.deviceName,
    );
    switch (result) {
      case Ok<AuthenticatedSession>():
        emit(state.copyWith(status: FormStatus.succeeded));
      case Err<AuthenticatedSession>(:final AppFailure failure):
        emit(state.copyWith(status: FormStatus.editing, errors: registrationErrorsFor(failure)));
    }
  }
}
