import 'package:equatable/equatable.dart';

import '../services/permission_steps.dart';
import 'management_level.dart';
import 'permission_facts.dart';
import 'permission_step.dart';

/// Situacao das permissoes do controle neste aparelho, pronta para a tela: os passos na ordem
/// em que devem ser resolvidos, o proximo a destacar e o andamento das obrigatorias.
final class PermissionPlan extends Equatable {
  PermissionPlan({required this.facts, required this.manufacturer})
    : steps = List<PermissionStep>.unmodifiable(
        buildPermissionSteps(facts, manufacturer: manufacturer),
      );

  final PermissionFacts facts;

  /// Fabricante do aparelho. Vazio quando o sistema nao informou.
  final String manufacturer;
  final List<PermissionStep> steps;

  ManagementLevel get management => facts.management;

  /// Proximo passo a resolver, destacado na tela.
  PermissionStep? get next => nextPendingStep(steps);

  int get requiredTotal => requiredCount(steps);

  int get requiredGranted => grantedRequiredCount(steps);

  /// Verdadeiro quando todas as permissoes obrigatorias estao ligadas.
  bool get isComplete => requiredPermissionsGranted(steps);

  /// Verdadeiro quando o passo e a acessibilidade pendente em um aparelho que provavelmente
  /// exige liberar as "configuracoes restritas" antes.
  bool needsRestrictedSettingsHint(PermissionStep step) {
    return step.kind == PermissionKind.accessibility &&
        step.isPending &&
        facts.restrictedSettingsLikely;
  }

  /// O mesmo fabricante com as permissoes relidas.
  PermissionPlan withFacts(PermissionFacts facts) {
    return PermissionPlan(facts: facts, manufacturer: manufacturer);
  }

  @override
  List<Object?> get props => <Object?>[facts, manufacturer];
}
