import 'package:equatable/equatable.dart';

/// Tempo extra concedido para um dia da cota.
final class ExtraTimeGrant extends Equatable {
  const ExtraTimeGrant({
    required this.id,
    required this.day,
    required this.minutes,
    required this.grantedAt,
  });

  /// Identificador unico: reenviar a mesma concessao nao soma duas vezes.
  final String id;

  /// Dia da cota (AAAA-MM-DD).
  final String day;
  final int minutes;
  final int grantedAt;

  @override
  List<Object?> get props => <Object?>[id, day, minutes, grantedAt];
}

/// Bloqueio imediato pedido pelo responsavel ("Pausar agora").
final class ManualLock extends Equatable {
  const ManualLock({required this.active, this.until, this.setAt});

  static const ManualLock inactive = ManualLock(active: false);

  final bool active;

  /// Instante de liberacao automatica, ou nulo para "ate desbloquear".
  final int? until;
  final int? setAt;

  bool isActiveAt(int nowMs) {
    final int? limit = until;
    return active && (limit == null || limit > nowMs);
  }

  @override
  List<Object?> get props => <Object?>[active, until, setAt];
}

/// Escopos que uma suspensao temporaria de regras pode cobrir.
enum SuspensionScope {
  dailyLimit('Limite de tempo'),
  schedules('Horários e períodos de bloqueio'),
  appBlocks('Apps bloqueados');

  const SuspensionScope(this.label);

  final String label;
}

/// Suspensao temporaria de regras.
final class Suspension extends Equatable {
  const Suspension({required this.until, this.scopes = const <SuspensionScope>[], this.setAt});

  static const Suspension none = Suspension(until: 0);

  final int until;
  final List<SuspensionScope> scopes;
  final int? setAt;

  bool isActiveAt(int nowMs) => until > nowMs && scopes.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[until, scopes, setAt];
}

/// Comandos temporarios do responsavel. Alterados so pelas rotas de comando do servidor, que
/// incrementam a versao da politica: por isso sobrevivem a perda de conexao e sao
/// idempotentes.
final class PolicyOverrides extends Equatable {
  const PolicyOverrides({
    this.extraTime = const <ExtraTimeGrant>[],
    this.manualLock = ManualLock.inactive,
    this.suspension = Suspension.none,
  });

  final List<ExtraTimeGrant> extraTime;
  final ManualLock manualLock;
  final Suspension suspension;

  /// Minutos extras concedidos para o dia da cota informado.
  int extraMinutesFor(String day) {
    return extraTime
        .where((ExtraTimeGrant grant) => grant.day == day)
        .fold<int>(0, (int total, ExtraTimeGrant grant) => total + grant.minutes);
  }

  @override
  List<Object?> get props => <Object?>[extraTime, manualLock, suspension];
}
