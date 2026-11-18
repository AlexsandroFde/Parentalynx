import 'package:equatable/equatable.dart';

import '../../../app_management/domain/entities/allowed_app.dart';
import '../../../app_management/domain/entities/app_usage.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../screen_time/domain/entities/child_time_request.dart';

/// Dados da tela inicial da crianca que mudam devagar: regras, uso por app, apps liberados e
/// pedidos de tempo.
final class ChildHomeSummary extends Equatable {
  const ChildHomeSummary({
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
  final List<ChildTimeRequest> requests;

  @override
  List<Object?> get props => <Object?>[policy, usage, exceptions, requests];
}
