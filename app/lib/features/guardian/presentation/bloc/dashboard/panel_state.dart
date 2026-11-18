import 'package:equatable/equatable.dart';

import '../../../../../core/errors/app_failure.dart';

/// Estado de um cartao do painel que carrega o seu proprio dado (politica, apps, alertas).
///
/// Cada cartao carrega sem segurar os outros. Uma atualizacao em segundo plano que falha
/// mantem o dado anterior: so a primeira carga mostra a falha.
sealed class PanelState<T> extends Equatable {
  const PanelState();

  /// Dado carregado, ou nulo.
  T? get valueOrNull => null;

  @override
  List<Object?> get props => const <Object?>[];
}

/// Carregando pela primeira vez.
final class PanelLoading<T> extends PanelState<T> {
  const PanelLoading();
}

/// Dado carregado.
final class PanelLoaded<T> extends PanelState<T> {
  const PanelLoaded(this.value);

  final T value;

  @override
  T get valueOrNull => value;

  @override
  List<Object?> get props => <Object?>[value];
}

/// A primeira carga falhou.
final class PanelFailed<T> extends PanelState<T> {
  const PanelFailed(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}
