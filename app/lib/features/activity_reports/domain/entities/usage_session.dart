import 'package:equatable/equatable.dart';

import '../../../app_management/domain/entities/app_entry.dart';

/// Sessao de uso de um app (protocolo, secao 6).
final class UsageSession extends Equatable {
  const UsageSession({
    required this.package,
    required this.label,
    required this.category,
    required this.start,
    required this.end,
    required this.durationMs,
    required this.tzOffsetMin,
  });

  final String package;
  final String label;
  final AppCategory category;
  final int start;
  final int end;
  final int durationMs;

  /// Diferenca do fuso do aparelho para UTC no momento da sessao, em minutos.
  final int tzOffsetMin;

  /// Inicio no relogio local do aparelho da crianca (como instante UTC deslocado).
  DateTime get localStart {
    return DateTime.fromMillisecondsSinceEpoch(start + tzOffsetMin * 60000, isUtc: true);
  }

  DateTime get localEnd {
    return DateTime.fromMillisecondsSinceEpoch(end + tzOffsetMin * 60000, isUtc: true);
  }

  @override
  List<Object?> get props => <Object?>[
    package,
    label,
    category,
    start,
    end,
    durationMs,
    tzOffsetMin,
  ];
}
