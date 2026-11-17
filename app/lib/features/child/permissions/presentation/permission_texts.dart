import 'package:material_ui/material_ui.dart';

import '../../agent/domain/child_models.dart';
import '../domain/permission_steps.dart';

/// Textos e icone de um passo de permissao.
class PermissionStepText {
  const PermissionStepText({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
  });

  final IconData icon;
  final String title;

  /// Para que serve, em uma ou duas frases.
  final String description;
  final String actionLabel;
}

PermissionStepText permissionStepText(PermissionKind kind) {
  return switch (kind) {
    PermissionKind.usageAccess => const PermissionStepText(
      icon: Icons.timelapse_rounded,
      title: 'Acesso ao uso',
      description:
          'Deixa o app saber quanto tempo cada aplicativo foi usado. É assim que o tempo do '
          'dia é contado.',
      actionLabel: 'Permitir acesso ao uso',
    ),
    PermissionKind.accessibility => const PermissionStepText(
      icon: Icons.accessibility_new_rounded,
      title: 'Acessibilidade',
      description:
          'Deixa o app perceber na hora qual aplicativo está aberto, para fechar um app '
          'bloqueado.',
      actionLabel: 'Ativar acessibilidade',
    ),
    PermissionKind.notifications => const PermissionStepText(
      icon: Icons.notifications_outlined,
      title: 'Notificações',
      description: 'Mostra o tempo que falta e avisa quando ele está acabando.',
      actionLabel: 'Permitir notificações',
    ),
    PermissionKind.batteryOptimization => const PermissionStepText(
      icon: Icons.battery_charging_full_rounded,
      title: 'Bateria sem restrição',
      description: 'Evita que o Android desligue o controle para economizar bateria.',
      actionLabel: 'Liberar a bateria',
    ),
    PermissionKind.overlay => const PermissionStepText(
      icon: Icons.layers_outlined,
      title: 'Aparecer sobre outros apps',
      description:
          'É um reforço: deixa o app mostrar a tela de bloqueio mesmo se a acessibilidade '
          'for desligada.',
      actionLabel: 'Permitir',
    ),
    PermissionKind.exactAlarms => const PermissionStepText(
      icon: Icons.alarm_rounded,
      title: 'Alarmes exatos',
      description:
          'Faz o aparelho ser liberado ou bloqueado na hora certa, mesmo com a tela apagada.',
      actionLabel: 'Permitir alarmes',
    ),
    PermissionKind.deviceAdmin => const PermissionStepText(
      icon: Icons.admin_panel_settings_outlined,
      title: 'Administrador do dispositivo',
      description:
          'Reforço opcional: para desinstalar o app será preciso desativar o administrador '
          'antes, e o responsável é avisado.',
      actionLabel: 'Ativar administrador',
    ),
    PermissionKind.autostart => const PermissionStepText(
      icon: Icons.restart_alt_rounded,
      title: 'Início automático',
      description:
          'Neste aparelho os apps não ligam sozinhos depois de reiniciar. Libere o início '
          'automático do ParentaLynx nas configurações.',
      actionLabel: 'Abrir configurações',
    ),
  };
}

/// O que o servico de acessibilidade faz e o que ele nao faz. Mostrado em destaque antes de
/// a pessoa ir ate as configuracoes.
const String accessibilityDisclosure =
    'O ParentaLynx usa a acessibilidade só para saber qual aplicativo está aberto e para '
    'fechar um app bloqueado. Ele NÃO lê o que aparece na tela, NÃO registra o que é digitado '
    'e NÃO vê senhas nem mensagens.';

/// Orientacao para apps instalados por fora da loja em Android 13 ou superior.
const String restrictedSettingsHint =
    'Se a opção aparecer apagada nas configurações, abra as informações do app, toque nos '
    'três pontinhos no canto de cima e escolha "Permitir configurações restritas". Depois '
    'volte aqui e ative a acessibilidade.';

/// O que cada nivel de gerenciamento garante, em linguagem simples.
class ManagementText {
  const ManagementText({
    required this.title,
    required this.guaranteed,
    required this.notGuaranteed,
  });

  final String title;
  final String guaranteed;
  final String notGuaranteed;
}

ManagementText managementText(ManagementLevel level) {
  return switch (level) {
    ManagementLevel.standard => const ManagementText(
      title: 'Proteção padrão',
      guaranteed:
          'Com as permissões abaixo ligadas, o app conta o tempo de uso e fecha os apps '
          'bloqueados.',
      notGuaranteed:
          'Quem está com o aparelho consegue desligar as permissões ou desinstalar o app. '
          'Quando isso acontece, o responsável é avisado.',
    ),
    ManagementLevel.deviceAdmin => const ManagementText(
      title: 'Proteção padrão com administrador',
      guaranteed:
          'Com as permissões abaixo ligadas, o app conta o tempo de uso e fecha os apps '
          'bloqueados. Para desinstalar é preciso desativar o administrador antes.',
      notGuaranteed:
          'Quem está com o aparelho ainda consegue desligar as permissões. O responsável é '
          'avisado quando isso acontece.',
    ),
    ManagementLevel.deviceOwner => const ManagementText(
      title: 'Dispositivo gerenciado',
      guaranteed:
          'O próprio Android impede abrir os apps bloqueados e desinstalar o controle. O '
          'bloqueio continua valendo mesmo se o app for fechado.',
      notGuaranteed:
          'Uma restauração de fábrica feita pelo modo de recuperação ainda remove o controle.',
    ),
  };
}
