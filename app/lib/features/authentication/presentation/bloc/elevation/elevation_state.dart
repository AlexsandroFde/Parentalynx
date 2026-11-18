part of 'elevation_bloc.dart';

final class ElevationState extends Equatable {
  const ElevationState({this.status = FormStatus.editing, this.error});

  final FormStatus status;
  final String? error;

  @override
  List<Object?> get props => <Object?>[status, error];
}
