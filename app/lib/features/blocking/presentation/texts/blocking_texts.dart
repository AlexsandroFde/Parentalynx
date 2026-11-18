import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../domain/entities/system_lock.dart';

/// Textos das regras de bloqueio: resumos da visao geral e garantias de cada modo.

/// Resumo da navegacao na internet para a visao geral das regras.
String webSummary(WebPolicy web) {
  if (!web.managedBrowser) {
    return 'Navegador ParentaLynx desligado';
  }
  if (web.mode == WebMode.allowlist) {
    final int count = web.allowedDomains.length;
    return count == 1 ? 'Só 1 site autorizado' : 'Só $count sites autorizados';
  }
  final int categories = web.blockedCategories.length;
  final int domains = web.blockedDomains.length;
  final List<String> parts = <String>[
    if (categories > 0) '$categories ${categories == 1 ? 'categoria' : 'categorias'}',
    if (domains > 0) '$domains ${domains == 1 ? 'site' : 'sites'}',
    if (web.safeDns) 'filtro familiar',
  ];
  return parts.isEmpty ? 'Navegador ParentaLynx sem filtros' : 'Bloqueia: ${parts.join(', ')}';
}

/// Resumo da protecao para a visao geral das regras.
String protectionSummary(ProtectionPolicy protection, DeviceManagementMode mode) {
  final String tamper = protection.lockOnTamper
      ? 'Bloqueia se a proteção for desativada'
      : 'Só avisa se a proteção for desativada';
  if (!SystemLock.availableIn(mode)) {
    return tamper;
  }
  final int active = SystemLock.countEnabled(protection);
  return '$tamper. $active de ${SystemLock.values.length} travas do sistema ativas';
}

/// O que cada modo de gerenciamento garante e o que nao garante (resumo de
/// `docs/01-capacidades-android.md`). Usado na tela de protecao e no painel.
({List<String> guaranteed, List<String> notGuaranteed}) guaranteesOf(DeviceManagementMode mode) {
  switch (mode) {
    case DeviceManagementMode.deviceOwner:
      return (
        guaranteed: const <String>[
          'Apps bloqueados são suspensos pelo sistema e não chegam a abrir.',
          'O bloqueio continua valendo depois de reiniciar e se o app for encerrado.',
          'A desinstalação e o modo de segurança podem ser impedidos.',
        ],
        notGuaranteed: const <String>[
          'A restauração pelo modo de recuperação do aparelho não pode ser impedida.',
        ],
      );
    case DeviceManagementMode.deviceAdmin:
      return (
        guaranteed: const <String>[
          'Contagem de tempo e bloqueio de apps funcionam enquanto as permissões estiverem '
              'ativas.',
          'Desinstalar exige desativar o administrador antes, e isso gera um alerta.',
        ],
        notGuaranteed: const <String>[
          'A criança consegue desativar as permissões. Você é avisado quando isso acontece.',
          'Modo de segurança e restauração de fábrica não podem ser impedidos.',
        ],
      );
    case DeviceManagementMode.standard:
      return (
        guaranteed: const <String>[
          'Contagem de tempo e bloqueio de apps funcionam enquanto as permissões estiverem '
              'ativas.',
          'Toda adulteração que o app consegue detectar gera um alerta.',
        ],
        notGuaranteed: const <String>[
          'A criança consegue desativar as permissões ou desinstalar o app.',
          'Um app bloqueado pode aparecer por uma fração de segundo antes do bloqueio.',
          'Modo de segurança e restauração de fábrica não podem ser impedidos.',
        ],
      );
  }
}
