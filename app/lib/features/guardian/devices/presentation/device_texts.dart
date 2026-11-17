import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../domain/device.dart';

/// Textos e rotulos sobre aparelhos, usados na lista e no detalhe.

/// O que o modo de gerenciamento garante e o que nao garante. Resumo de
/// `docs/01-capacidades-android.md`, secao 3.
class ManagementModeInfo {
  const ManagementModeInfo({
    required this.summary,
    required this.guaranteed,
    required this.notGuaranteed,
  });

  final String summary;
  final List<String> guaranteed;
  final List<String> notGuaranteed;

  static ManagementModeInfo of(DeviceManagementMode mode) {
    return switch (mode) {
      DeviceManagementMode.standard => const ManagementModeInfo(
        summary:
            'Instalação comum. O controle funciona enquanto as permissões estiverem ativas '
            'e avisa você se alguma for desativada.',
        guaranteed: <String>[
          'Conta o tempo de uso por aplicativo.',
          'Tira da tela os apps bloqueados (o app pode aparecer por uma fração de segundo).',
          'Mantém as regras sem internet e depois de reiniciar o aparelho.',
        ],
        notGuaranteed: <String>[
          'Não impede desinstalar o ParentaLynx. Você é avisado quando o aparelho para de '
              'sincronizar.',
          'Não impede desativar as permissões. Você recebe um alerta.',
          'Não impede o modo de segurança nem a restauração de fábrica.',
        ],
      ),
      DeviceManagementMode.deviceAdmin => const ManagementModeInfo(
        summary:
            'Instalação comum com o administrador do dispositivo ativado: desinstalar '
            'exige um passo a mais, que gera alerta.',
        guaranteed: <String>[
          'Conta o tempo de uso por aplicativo.',
          'Tira da tela os apps bloqueados (o app pode aparecer por uma fração de segundo).',
          'Desinstalar exige desativar o administrador antes, e isso gera um alerta.',
        ],
        notGuaranteed: <String>[
          'A criança ainda consegue desativar o administrador e as permissões.',
          'Não impede o modo de segurança nem a restauração de fábrica.',
        ],
      ),
      DeviceManagementMode.deviceOwner => const ManagementModeInfo(
        summary:
            'Dispositivo totalmente gerenciado: o próprio Android impõe o bloqueio, mesmo se '
            'o aplicativo parar.',
        guaranteed: <String>[
          'O sistema suspende os apps bloqueados: eles nem chegam a abrir.',
          'Desinstalar, forçar parada e limpar dados do ParentaLynx são impedidos.',
          'Modo de segurança e restauração pelas Configurações ficam bloqueados.',
          'Data e hora protegidas e filtro DNS no sistema inteiro.',
        ],
        notGuaranteed: <String>[
          'A restauração pelo modo de recuperação do aparelho continua possível.',
          'O histórico de navegação só existe no navegador gerenciado.',
        ],
      ),
    };
  }
}

/// Uma permissao do aparelho com o seu estado e a sua importancia.
class PermissionLine {
  const PermissionLine({
    required this.label,
    required this.purpose,
    required this.granted,
    required this.essential,
  });

  final String label;
  final String purpose;
  final bool granted;

  /// Falso para permissoes de reforco, que nao impedem o controle de funcionar.
  final bool essential;

  static List<PermissionLine> of(DevicePermissions permissions) {
    return <PermissionLine>[
      PermissionLine(
        label: 'Acesso ao uso',
        purpose: 'Conta o tempo de cada aplicativo.',
        granted: permissions.usageAccess,
        essential: true,
      ),
      PermissionLine(
        label: 'Acessibilidade',
        purpose: 'Percebe na hora o app aberto e tira da tela o que está bloqueado.',
        granted: permissions.accessibility,
        essential: true,
      ),
      PermissionLine(
        label: 'Notificações',
        purpose: 'Mostra o tempo restante e os avisos para a criança.',
        granted: permissions.notifications,
        essential: true,
      ),
      PermissionLine(
        label: 'Bateria sem restrição',
        purpose: 'Evita que o sistema encerre o controle em segundo plano.',
        granted: permissions.batteryOptimizationIgnored,
        essential: false,
      ),
      PermissionLine(
        label: 'Sobrepor a outros apps',
        purpose: 'Reforço para mostrar a tela de bloqueio se a acessibilidade cair.',
        granted: permissions.overlay,
        essential: false,
      ),
      PermissionLine(
        label: 'Alarmes exatos',
        purpose: 'Libera o aparelho na hora certa do reinício da cota.',
        granted: permissions.exactAlarms,
        essential: false,
      ),
      PermissionLine(
        label: 'Administrador do dispositivo',
        purpose: 'Opcional. Dificulta a desinstalação.',
        granted: permissions.deviceAdmin,
        essential: false,
      ),
    ];
  }
}

/// Texto de um problema de aplicacao das regras (`enforcement.issues` do protocolo).
String issueLabel(String code) {
  return switch (code) {
    'accessibility_disabled' =>
      'O serviço de acessibilidade está desativado: o bloqueio de apps ficou mais lento ou '
          'indisponível.',
    'usage_access_missing' => 'Sem acesso ao uso: a contagem de tempo está menos precisa.',
    'overlay_missing' => 'Sem permissão de sobreposição: não há reforço para a tela de bloqueio.',
    'notifications_disabled' => 'Notificações desativadas: a criança não vê os avisos de tempo.',
    'battery_optimized' => 'A economia de bateria pode encerrar o controle em segundo plano.',
    'suspend_failed' => 'O sistema recusou suspender algum aplicativo.',
    'policy_invalid' => 'O aparelho não conseguiu ler as regras recebidas.',
    'clock_untrusted' => 'O relógio do aparelho não pôde ser conferido com o servidor.',
    _ => 'Problema informado pelo aparelho: $code',
  };
}

/// Situacao de conexao de um aparelho ativo, para a etiqueta da lista e do detalhe.
({String label, Tone tone, IconData icon}) connectionStatus(Device device, {DateTime? now}) {
  if (device.online) {
    return (label: 'Online', tone: Tone.success, icon: Icons.wifi);
  }
  final int? lastSync = device.lastSyncAt;
  if (lastSync == null) {
    return (label: 'Nunca sincronizou', tone: Tone.warning, icon: Icons.sync_problem);
  }
  return (
    label: 'Visto ${formatRelativeMs(lastSync, now: now)}',
    tone: Tone.neutral,
    icon: Icons.cloud_off_outlined,
  );
}
