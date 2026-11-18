part of 'elevation_bloc.dart';

sealed class ElevationEvent extends Equatable {
  const ElevationEvent();
}

/// O responsavel confirmou a senha administrativa.
final class ElevationSubmitted extends ElevationEvent {
  const ElevationSubmitted(this.password);

  final String password;

  @override
  List<Object?> get props => <Object?>[password];
}
