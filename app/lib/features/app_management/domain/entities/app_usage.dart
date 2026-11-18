import 'package:equatable/equatable.dart';

/// Tempo de uso de um app hoje, neste aparelho (modo crianca).
final class AppUsage extends Equatable {
  const AppUsage({
    required this.packageName,
    required this.label,
    required this.ms,
    required this.opens,
  });

  final String packageName;
  final String label;
  final int ms;
  final int opens;

  @override
  List<Object?> get props => <Object?>[packageName, label, ms, opens];
}
