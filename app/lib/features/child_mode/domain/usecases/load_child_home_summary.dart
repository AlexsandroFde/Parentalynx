import '../../../../core/result/result.dart';
import '../../../app_management/domain/entities/allowed_app.dart';
import '../../../app_management/domain/entities/app_usage.dart';
import '../../../app_management/domain/usecases/get_always_allowed_apps.dart';
import '../../../app_management/domain/usecases/get_today_app_usage.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/domain/usecases/get_active_policy.dart';
import '../../../screen_time/domain/entities/child_time_request.dart';
import '../../../screen_time/domain/usecases/get_own_time_requests.dart';
import '../entities/child_home_summary.dart';

/// Junta os dados da tela inicial da crianca que mudam devagar: regras em vigor, uso de hoje,
/// apps sempre liberados e pedidos de tempo. As quatro consultas ao agente correm juntas.
class LoadChildHomeSummary {
  const LoadChildHomeSummary({
    required this._getActivePolicy,
    required this._getTodayAppUsage,
    required this._getAlwaysAllowedApps,
    required this._getOwnTimeRequests,
  });

  final GetActivePolicy _getActivePolicy;
  final GetTodayAppUsage _getTodayAppUsage;
  final GetAlwaysAllowedApps _getAlwaysAllowedApps;
  final GetOwnTimeRequests _getOwnTimeRequests;

  Future<Result<ChildHomeSummary>> call() async {
    final (
      Result<Policy?> policy,
      Result<List<AppUsage>> usage,
      Result<List<AllowedApp>> exceptions,
      Result<List<ChildTimeRequest>> requests,
    ) = await (
      _getActivePolicy(),
      _getTodayAppUsage(),
      _getAlwaysAllowedApps(),
      _getOwnTimeRequests(),
    ).wait;
    return switch ((policy, usage, exceptions, requests)) {
      (
        Ok<Policy?>(value: final Policy? policy),
        Ok<List<AppUsage>>(value: final List<AppUsage> usage),
        Ok<List<AllowedApp>>(value: final List<AllowedApp> exceptions),
        Ok<List<ChildTimeRequest>>(value: final List<ChildTimeRequest> requests),
      ) =>
        Ok<ChildHomeSummary>(
          ChildHomeSummary(
            policy: policy,
            usage: usage,
            exceptions: exceptions,
            requests: requests,
          ),
        ),
      _ => Err<ChildHomeSummary>(
        (policy.failureOrNull ??
            usage.failureOrNull ??
            exceptions.failureOrNull ??
            requests.failureOrNull)!,
      ),
    };
  }
}
