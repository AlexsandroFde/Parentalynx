import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../shared/domain/policy.dart';
import '../../agent/data/child_agent_repository.dart';
import '../../agent/domain/child_models.dart';
import '../../agent/presentation/child_session.dart';
import '../../shared/no_retry.dart';

/// Dados da tela inicial que mudam devagar: regras, uso por app, apps liberados e pedidos.
class ChildHomeData {
  const ChildHomeData({
    required this.policy,
    required this.usage,
    required this.exceptions,
    required this.requests,
  });

  /// Nulo quando o agente ainda nao tem politica.
  final Policy? policy;

  /// Uso de hoje por app, do mais usado para o menos usado.
  final List<AppUsage> usage;
  final List<AllowedApp> exceptions;

  /// Pedidos de tempo, do mais recente para o mais antigo.
  final List<TimeRequest> requests;
}

/// Intervalo de atualizacao dos dados que mudam devagar.
const Duration childHomeRefreshInterval = Duration(seconds: 15);

final childHomeDataProvider =
    AsyncNotifierProvider.autoDispose<ChildHomeDataController, ChildHomeData>(
      ChildHomeDataController.new,
      retry: noRetry,
    );

class ChildHomeDataController extends AsyncNotifier<ChildHomeData> {
  Timer? _timer;
  bool _busy = false;

  @override
  Future<ChildHomeData> build() {
    _timer?.cancel();
    _timer = Timer.periodic(childHomeRefreshInterval, (Timer timer) {
      if (ref.read(childForegroundProvider)) {
        unawaited(refresh());
      }
    });
    ref.onDispose(() => _timer?.cancel());
    return _load(ref.read(childAgentRepositoryProvider));
  }

  /// Recarrega mantendo o que esta na tela se a consulta falhar.
  Future<void> refresh() async {
    if (_busy) {
      return;
    }
    _busy = true;
    try {
      final ChildHomeData data = await _load(ref.read(childAgentRepositoryProvider));
      if (ref.mounted) {
        state = AsyncData<ChildHomeData>(data);
      }
    } on AppFailure catch (error, stack) {
      if (ref.mounted && !state.hasValue) {
        state = AsyncError<ChildHomeData>(error, stack);
      }
    } finally {
      _busy = false;
    }
  }

  static Future<ChildHomeData> _load(ChildAgentRepository agent) async {
    final (
      Policy? policy,
      List<AppUsage> usage,
      List<AllowedApp> exceptions,
      List<TimeRequest> requests,
    ) = await (
      agent.policy(),
      agent.todayUsage(),
      agent.exceptionApps(),
      agent.timeRequests(),
    ).wait;
    return ChildHomeData(
      policy: policy,
      usage: <AppUsage>[...usage]..sort((AppUsage a, AppUsage b) => b.ms.compareTo(a.ms)),
      exceptions: exceptions,
      requests: <TimeRequest>[...requests]
        ..sort((TimeRequest a, TimeRequest b) => b.createdAtMs.compareTo(a.createdAtMs)),
    );
  }
}
