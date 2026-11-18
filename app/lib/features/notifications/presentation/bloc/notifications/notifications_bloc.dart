import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/action_status.dart';
import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../../core/time/clock.dart';
import '../../../domain/entities/guardian_alert.dart';
import '../../../domain/usecases/get_unread_alerts_count.dart';
import '../../../domain/usecases/load_latest_alerts.dart';
import '../../../domain/usecases/load_older_alerts.dart';
import '../../../domain/usecases/mark_alert_read.dart';
import '../../../domain/usecases/mark_alerts_seen.dart';
import '../../../domain/usecases/mark_all_alerts_read.dart';
import '../../../domain/usecases/watch_incoming_alerts.dart';

part 'notifications_event.dart';
part 'notifications_state.dart';

/// Notificacoes e alertas do responsavel: selo de nao lidos, central de alertas e chegada em
/// tempo real.
///
/// Vive enquanto o painel estiver aberto, para o selo da barra de abas e a central mostrarem
/// sempre os mesmos numeros.
class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc({
    required this._loadLatest,
    required this._loadOlder,
    required this._unreadCount,
    required this._markRead,
    required this._markAllRead,
    required this._incoming,
    required this._markSeen,
    required this._clock,
  }) : super(const NotificationsState()) {
    on<NotificationsStarted>(_onStarted, transformer: restartable());
    on<AlertsFeedRequested>(_onFeedRequested, transformer: droppable());
    on<AlertsRefreshRequested>(_onRefreshRequested, transformer: droppable());
    on<OlderAlertsRequested>(_onOlderRequested, transformer: droppable());
    on<AlertReadRequested>(_onReadRequested, transformer: sequential());
    on<AllAlertsReadRequested>(_onAllReadRequested, transformer: droppable());
    on<_IncomingAlertReceived>(_onIncoming, transformer: sequential());
  }

  final LoadLatestAlerts _loadLatest;
  final LoadOlderAlerts _loadOlder;
  final GetUnreadAlertsCount _unreadCount;
  final MarkAlertRead _markRead;
  final MarkAllAlertsRead _markAllRead;
  final WatchIncomingAlerts _incoming;
  final MarkAlertsSeen _markSeen;
  final Clock _clock;

  Future<void> _onStarted(NotificationsStarted event, Emitter<NotificationsState> emit) async {
    await Future.wait(<Future<void>>[
      emit.onEach<GuardianAlert>(
        _incoming(),
        onData: (GuardianAlert alert) => add(_IncomingAlertReceived(alert)),
      ),
      () async {
        // Sem rede o selo fica como esta e e atualizado na proxima vez.
        final Result<int> unread = await _unreadCount();
        if (unread case Ok<int>(:final int value) when !emit.isDone) {
          emit(state.copyWith(unread: value));
        }
      }(),
    ]);
  }

  Future<void> _onFeedRequested(AlertsFeedRequested event, Emitter<NotificationsState> emit) async {
    if (state.feed is AlertsFeedLoaded || state.feed is AlertsFeedLoading) {
      return;
    }
    emit(state.copyWith(feed: const AlertsFeedLoading()));
    final Result<AlertsPage> result = await _loadLatest();
    switch (result) {
      case Ok<AlertsPage>(:final AlertsPage value):
        emit(state.copyWith(unread: value.unread, feed: _firstPage(value)));
      case Err<AlertsPage>(:final AppFailure failure):
        emit(state.copyWith(feed: AlertsFeedError(failure)));
    }
  }

  Future<void> _onRefreshRequested(
    AlertsRefreshRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      final Result<AlertsPage> result = await _loadLatest();
      switch (result) {
        case Ok<AlertsPage>(:final AlertsPage value):
          emit(state.copyWith(unread: value.unread, feed: _firstPage(value)));
        case Err<AlertsPage>(:final AppFailure failure):
          // Mantem a lista atual se a recarga falhar.
          if (state.feed is! AlertsFeedLoaded) {
            emit(state.copyWith(feed: AlertsFeedError(failure)));
          }
      }
    } finally {
      event.completer?.complete();
    }
  }

  Future<void> _onOlderRequested(
    OlderAlertsRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final AlertsFeed current = state.feed;
    if (current is! AlertsFeedLoaded ||
        !current.hasMore ||
        current.loadingMore ||
        current.alerts.isEmpty) {
      return;
    }
    emit(state.copyWith(feed: current.copyWith(loadingMore: true), action: const ActionRunning()));
    final Result<AlertsPage> result = await _loadOlder(current.alerts.last.id);
    final AlertsFeed latest = state.feed;
    final AlertsFeedLoaded base = latest is AlertsFeedLoaded ? latest : current;
    switch (result) {
      case Ok<AlertsPage>(:final AlertsPage value):
        emit(
          state.copyWith(
            feed: base.copyWith(
              alerts: <GuardianAlert>[...base.alerts, ...value.alerts],
              hasMore: value.alerts.length >= LoadLatestAlerts.pageSize,
              loadingMore: false,
            ),
            action: const ActionIdle(),
          ),
        );
      case Err<AlertsPage>(:final AppFailure failure):
        emit(
          state.copyWith(
            feed: base.copyWith(loadingMore: false),
            action: actionStatusForFailure(failure),
          ),
        );
    }
  }

  Future<void> _onReadRequested(AlertReadRequested event, Emitter<NotificationsState> emit) async {
    final AlertsFeed current = state.feed;
    if (current is! AlertsFeedLoaded) {
      return;
    }
    GuardianAlert? target;
    for (final GuardianAlert alert in current.alerts) {
      if (alert.id == event.alertId) {
        target = alert;
      }
    }
    if (target == null || target.isRead) {
      return;
    }
    final int now = _clock.nowMs();
    emit(
      state.copyWith(
        feed: _mapAlerts(
          current,
          (GuardianAlert alert) => alert.id == event.alertId ? alert.markedRead(now) : alert,
        ),
      ),
    );
    // Falha mantem a marcacao local. Na proxima recarga o servidor e a referencia.
    final Result<int> result = await _markRead(event.alertId);
    if (result case Ok<int>(:final int value)) {
      emit(state.copyWith(unread: value));
    }
  }

  Future<void> _onAllReadRequested(
    AllAlertsReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(state.copyWith(action: const ActionRunning()));
    final Result<int> result = await _markAllRead();
    switch (result) {
      case Ok<int>(:final int value):
        final int now = _clock.nowMs();
        final AlertsFeed feed = state.feed;
        emit(
          state.copyWith(
            unread: value,
            feed: feed is AlertsFeedLoaded
                ? _mapAlerts(feed, (GuardianAlert alert) => alert.markedRead(now))
                : feed,
            action: const ActionIdle(),
          ),
        );
      case Err<int>(:final AppFailure failure):
        emit(state.copyWith(action: actionStatusForFailure(failure)));
    }
  }

  void _onIncoming(_IncomingAlertReceived event, Emitter<NotificationsState> emit) {
    final GuardianAlert alert = event.alert;
    final AlertsFeed feed = state.feed;
    AlertsFeed nextFeed = feed;
    if (feed is AlertsFeedLoaded && !feed.alerts.any((GuardianAlert a) => a.id == alert.id)) {
      nextFeed = feed.copyWith(
        alerts: <GuardianAlert>[alert, ...feed.alerts],
        latestId: alert.id > feed.latestId ? alert.id : feed.latestId,
      );
    }
    emit(state.copyWith(unread: state.unread + 1, feed: nextFeed, lastIncoming: alert));
    unawaited(_markSeen(alert.id));
  }

  static AlertsFeedLoaded _firstPage(AlertsPage page) {
    return AlertsFeedLoaded(
      alerts: page.alerts,
      hasMore: page.alerts.length >= LoadLatestAlerts.pageSize,
      latestId: page.latestId,
    );
  }

  static AlertsFeedLoaded _mapAlerts(
    AlertsFeedLoaded feed,
    GuardianAlert Function(GuardianAlert alert) transform,
  ) {
    return feed.copyWith(alerts: feed.alerts.map(transform).toList());
  }
}
