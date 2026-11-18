part of 'notifications_bloc.dart';

/// Lista da central de alertas.
sealed class AlertsFeed extends Equatable {
  const AlertsFeed();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A central ainda nao foi aberta.
final class AlertsFeedIdle extends AlertsFeed {
  const AlertsFeedIdle();
}

/// Carregando a primeira pagina.
final class AlertsFeedLoading extends AlertsFeed {
  const AlertsFeedLoading();
}

/// Alertas carregados, do mais novo para o mais antigo.
final class AlertsFeedLoaded extends AlertsFeed {
  const AlertsFeedLoaded({
    required this.alerts,
    required this.hasMore,
    required this.latestId,
    this.loadingMore = false,
  });

  final List<GuardianAlert> alerts;

  /// Verdadeiro enquanto houver alertas mais antigos para carregar.
  final bool hasMore;
  final int latestId;
  final bool loadingMore;

  AlertsFeedLoaded copyWith({
    List<GuardianAlert>? alerts,
    bool? hasMore,
    int? latestId,
    bool? loadingMore,
  }) {
    return AlertsFeedLoaded(
      alerts: alerts ?? this.alerts,
      hasMore: hasMore ?? this.hasMore,
      latestId: latestId ?? this.latestId,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }

  @override
  List<Object?> get props => <Object?>[alerts, hasMore, latestId, loadingMore];
}

/// A primeira pagina nao pode ser carregada. A central oferece tentar de novo.
final class AlertsFeedError extends AlertsFeed {
  const AlertsFeedError(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}

/// Alertas do responsavel: o selo de nao lidos, a central e os avisos em tempo real.
final class NotificationsState extends Equatable {
  const NotificationsState({
    this.unread = 0,
    this.feed = const AlertsFeedIdle(),
    this.lastIncoming,
    this.action = const ActionIdle(),
  });

  /// Quantos alertas continuam nao lidos (selo da aba Alertas).
  final int unread;
  final AlertsFeed feed;

  /// Ultimo alerta que chegou com o painel aberto, para o aviso no topo da tela.
  final GuardianAlert? lastIncoming;

  /// Andamento de "marcar todos como lidos" e de "carregar mais antigos".
  final ActionStatus action;

  NotificationsState copyWith({
    int? unread,
    AlertsFeed? feed,
    GuardianAlert? lastIncoming,
    ActionStatus? action,
  }) {
    final int nextUnread = unread ?? this.unread;
    return NotificationsState(
      unread: nextUnread < 0 ? 0 : nextUnread,
      feed: feed ?? this.feed,
      lastIncoming: lastIncoming ?? this.lastIncoming,
      action: action ?? this.action,
    );
  }

  @override
  List<Object?> get props => <Object?>[unread, feed, lastIncoming, action];
}
