import '../../agent/domain/child_models.dart';

/// Permissoes e ajustes de que o controle parental depende neste aparelho.
enum PermissionKind {
  usageAccess,
  accessibility,
  notifications,
  batteryOptimization,
  overlay,
  exactAlarms,
  deviceAdmin,
  autostart,
}

enum PermissionImportance {
  /// Sem ela o controle nao funciona direito.
  required,

  /// Deixa o controle mais confiavel.
  recommended,

  /// Reforco que o responsavel pode escolher.
  optional,
}

class PermissionStep {
  const PermissionStep({required this.kind, required this.importance, required this.granted});

  final PermissionKind kind;
  final PermissionImportance importance;

  /// Nulo quando o sistema nao informa o estado (inicio automatico do fabricante).
  final bool? granted;

  bool get isPending => granted == false;

  bool get isRequired => importance == PermissionImportance.required;
}

/// Fabricantes que desligam o inicio automatico de apps por padrao.
const Set<String> _autostartManufacturers = <String>{
  'xiaomi',
  'redmi',
  'poco',
  'oppo',
  'realme',
  'vivo',
  'iqoo',
  'huawei',
  'honor',
  'oneplus',
  'tecno',
  'infinix',
  'itel',
  'meizu',
  'asus',
  'letv',
};

/// Verdadeiro quando o fabricante costuma exigir a liberacao manual do inicio automatico.
bool needsManufacturerAutostart(String manufacturer) {
  return _autostartManufacturers.contains(manufacturer.trim().toLowerCase());
}

/// Monta os passos de permissao, na ordem em que devem ser resolvidos.
///
/// No modo Device Owner o bloqueio e feito pelo proprio sistema, entao a acessibilidade deixa
/// de ser obrigatoria e a ativacao como administrador nao se aplica.
List<PermissionStep> buildPermissionSteps(PermissionFacts facts, {required String manufacturer}) {
  final bool owner = facts.deviceOwner;
  return <PermissionStep>[
    PermissionStep(
      kind: PermissionKind.usageAccess,
      importance: PermissionImportance.required,
      granted: facts.usageAccess,
    ),
    PermissionStep(
      kind: PermissionKind.accessibility,
      importance: owner ? PermissionImportance.recommended : PermissionImportance.required,
      granted: facts.accessibility,
    ),
    PermissionStep(
      kind: PermissionKind.notifications,
      importance: PermissionImportance.required,
      granted: facts.notifications,
    ),
    PermissionStep(
      kind: PermissionKind.batteryOptimization,
      importance: PermissionImportance.recommended,
      granted: facts.batteryOptimizationIgnored,
    ),
    PermissionStep(
      kind: PermissionKind.overlay,
      importance: PermissionImportance.recommended,
      granted: facts.overlay,
    ),
    // Em versoes do Android que nao exigem este acesso ele ja vem concedido e nao aparece.
    if (!facts.exactAlarms)
      const PermissionStep(
        kind: PermissionKind.exactAlarms,
        importance: PermissionImportance.recommended,
        granted: false,
      ),
    if (!owner)
      PermissionStep(
        kind: PermissionKind.deviceAdmin,
        importance: PermissionImportance.optional,
        granted: facts.deviceAdmin,
      ),
    if (needsManufacturerAutostart(manufacturer))
      const PermissionStep(
        kind: PermissionKind.autostart,
        importance: PermissionImportance.optional,
        granted: null,
      ),
  ];
}

/// Verdadeiro quando todas as permissoes obrigatorias estao concedidas.
bool requiredPermissionsGranted(List<PermissionStep> steps) {
  return steps.every((PermissionStep step) => !step.isRequired || step.granted == true);
}

/// Quantas permissoes obrigatorias ja foram concedidas.
int grantedRequiredCount(List<PermissionStep> steps) {
  return steps.where((PermissionStep step) => step.isRequired && step.granted == true).length;
}

int requiredCount(List<PermissionStep> steps) {
  return steps.where((PermissionStep step) => step.isRequired).length;
}

/// Primeiro passo ainda pendente, que a tela destaca como o proximo a resolver.
PermissionStep? nextPendingStep(List<PermissionStep> steps) {
  for (final PermissionStep step in steps) {
    if (step.isPending && step.isRequired) {
      return step;
    }
  }
  for (final PermissionStep step in steps) {
    if (step.isPending && step.importance == PermissionImportance.recommended) {
      return step;
    }
  }
  return null;
}
