import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/json/json_reader.dart';
import '../../../../core/platform/native_api.g.dart' show GuardianNativeApi;
import '../../../../core/platform/native_providers.dart';
import '../../realtime/guardian_realtime.dart';
import '../../shell/data/local_prefs.dart';
import '../data/api_alerts_repository.dart';
import '../domain/alert.dart';

/// Quantidade de alertas nao lidos, para o selo da aba Alertas.
final NotifierProvider<UnreadAlertsController, int> unreadAlertsProvider =
    NotifierProvider<UnreadAlertsController, int>(UnreadAlertsController.new);

class UnreadAlertsController extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) {
    state = value < 0 ? 0 : value;
  }

  void increment() {
    state = state + 1;
  }

  /// Busca a contagem no servidor. Falhas sao ignoradas: o selo continua com o valor atual.
  Future<void> refresh() async {
    try {
      final AlertsPage page = await ref.read(alertsRepositoryProvider).list(limit: 1);
      if (ref.mounted) {
        state = page.unread;
      }
    } on AppFailure {
      // Sem rede. O selo e atualizado na proxima vez.
    }
  }
}

/// Estado da central de alertas.
class AlertsState {
  const AlertsState({
    required this.alerts,
    required this.hasMore,
    this.loadingMore = false,
    this.latestId = 0,
  });

  final List<GuardianAlert> alerts;

  /// Verdadeiro enquanto houver alertas mais antigos para carregar.
  final bool hasMore;
  final bool loadingMore;
  final int latestId;

  AlertsState copyWith({
    List<GuardianAlert>? alerts,
    bool? hasMore,
    bool? loadingMore,
    int? latestId,
  }) {
    return AlertsState(
      alerts: alerts ?? this.alerts,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      latestId: latestId ?? this.latestId,
    );
  }
}

Duration? _noRetry(int retryCount, Object error) => null;

/// Central de alertas: primeira pagina, paginacao, leitura e chegada em tempo real.
final AsyncNotifierProvider<AlertsController, AlertsState> alertsProvider =
    AsyncNotifierProvider<AlertsController, AlertsState>(AlertsController.new, retry: _noRetry);

class AlertsController extends AsyncNotifier<AlertsState> {
  static const int pageSize = 30;

  @override
  Future<AlertsState> build() async {
    ref.listen<AsyncValue<GuardianRealtimeEvent>>(guardianRealtimeEventsProvider, (
      AsyncValue<GuardianRealtimeEvent>? previous,
      AsyncValue<GuardianRealtimeEvent> next,
    ) {
      final GuardianRealtimeEvent? event = next.value;
      if (event != null && event.type == 'alert') {
        _onRealtimeAlert(event);
      }
    });
    return _loadFirstPage();
  }

  Future<AlertsState> _loadFirstPage() async {
    final AlertsPage page = await ref.read(alertsRepositoryProvider).list(limit: pageSize);
    ref.read(unreadAlertsProvider.notifier).set(page.unread);
    _markSeen(page.latestId);
    return AlertsState(
      alerts: page.alerts,
      hasMore: page.alerts.length >= pageSize,
      latestId: page.latestId,
    );
  }

  /// Recarrega a primeira pagina mantendo a lista atual na tela enquanto a nova nao chega.
  Future<void> refresh() async {
    final AsyncValue<AlertsState> result = await AsyncValue.guard(_loadFirstPage);
    if (!ref.mounted) {
      return;
    }
    if (result.hasError && state.hasValue) {
      return;
    }
    state = result;
  }

  /// Carrega a pagina seguinte de alertas mais antigos.
  Future<void> loadMore() async {
    final AlertsState? current = state.value;
    if (current == null || !current.hasMore || current.loadingMore || current.alerts.isEmpty) {
      return;
    }
    state = AsyncData<AlertsState>(current.copyWith(loadingMore: true));
    try {
      final AlertsPage page = await ref
          .read(alertsRepositoryProvider)
          .list(before: current.alerts.last.id, limit: pageSize);
      if (!ref.mounted) {
        return;
      }
      final AlertsState latest = state.value ?? current;
      state = AsyncData<AlertsState>(
        latest.copyWith(
          alerts: <GuardianAlert>[...latest.alerts, ...page.alerts],
          hasMore: page.alerts.length >= pageSize,
          loadingMore: false,
        ),
      );
    } on Object {
      if (ref.mounted) {
        state = AsyncData<AlertsState>((state.value ?? current).copyWith(loadingMore: false));
      }
      rethrow;
    }
  }

  /// Marca um alerta como lido.
  Future<void> markRead(int alertId) async {
    final AlertsState? current = state.value;
    if (current == null) {
      return;
    }
    final GuardianAlert? target = current.alerts
        .where((GuardianAlert alert) => alert.id == alertId)
        .firstOrNull;
    if (target == null || target.isRead) {
      return;
    }
    final int now = ref.read(guardianClockProvider)().millisecondsSinceEpoch;
    _replaceAlerts((GuardianAlert alert) => alert.id == alertId ? alert.markedRead(now) : alert);
    try {
      final int unread = await ref.read(alertsRepositoryProvider).markRead(ids: <int>[alertId]);
      if (ref.mounted) {
        ref.read(unreadAlertsProvider.notifier).set(unread);
      }
    } on AppFailure {
      // A marcacao local fica. Na proxima recarga o servidor e a referencia.
    }
  }

  /// Marca todos os alertas como lidos.
  Future<void> markAllRead() async {
    final int unread = await ref.read(alertsRepositoryProvider).markRead(all: true);
    if (!ref.mounted) {
      return;
    }
    final int now = ref.read(guardianClockProvider)().millisecondsSinceEpoch;
    _replaceAlerts((GuardianAlert alert) => alert.markedRead(now));
    ref.read(unreadAlertsProvider.notifier).set(unread);
  }

  void _onRealtimeAlert(GuardianRealtimeEvent event) {
    final JsonMap? payload = event.payload.objOrNull('alert');
    if (payload == null) {
      return;
    }
    final GuardianAlert alert;
    try {
      alert = GuardianAlert.fromJson(payload);
    } on JsonFormatException {
      return;
    }
    final AlertsState? current = state.value;
    if (current == null || current.alerts.any((GuardianAlert item) => item.id == alert.id)) {
      return;
    }
    state = AsyncData<AlertsState>(
      current.copyWith(
        alerts: <GuardianAlert>[alert, ...current.alerts],
        latestId: alert.id > current.latestId ? alert.id : current.latestId,
      ),
    );
    _markSeen(alert.id);
  }

  void _replaceAlerts(GuardianAlert Function(GuardianAlert alert) transform) {
    final AlertsState? current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData<AlertsState>(
      current.copyWith(alerts: current.alerts.map(transform).toList()),
    );
  }

  /// Avisa o lado nativo de que estes alertas ja foram vistos, para a busca em segundo plano
  /// nao notificar de novo.
  void _markSeen(int alertId) {
    if (alertId <= 0) {
      return;
    }
    final GuardianNativeApi api = ref.read(guardianNativeApiProvider);
    unawaited(() async {
      try {
        await api.setLastSeenAlertId(alertId);
      } on PlatformException {
        // A ponte falhou. No pior caso um alerta ja visto gera uma notificacao.
      }
    }());
  }
}

/// Verdadeiro quando o sistema permite que o app mostre notificacoes. Nulo enquanto carrega.
final FutureProvider<bool> notificationsAllowedProvider = FutureProvider<bool>((Ref ref) async {
  try {
    final PermissionSnapshot snapshot = await ref.watch(deviceApiProvider).getPermissions();
    return snapshot.notifications;
  } on PlatformException {
    return true;
  }
});
