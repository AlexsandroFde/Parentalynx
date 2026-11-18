import 'package:material_ui/material_ui.dart';

import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/child_device.dart';

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

/// Problema de aplicacao das regras informado pelo aparelho (`enforcement.issues` do
/// protocolo), em linguagem de quem usa: o que aconteceu, o efeito e o que fazer.
({String title, String message}) describeIssue(String code) {
  return switch (code) {
    'accessibility_disabled' => (
      title: 'Serviço de acessibilidade desativado',
      message:
          'O bloqueio de apps pode não funcionar. No aparelho da criança, abra o ParentaLynx e '
          'reative a acessibilidade.',
    ),
    'usage_access_missing' => (
      title: 'Acesso ao uso desativado',
      message:
          'A contagem de tempo ficou imprecisa ou parou. No aparelho da criança, reative o '
          '"Acesso ao uso" do ParentaLynx.',
    ),
    'overlay_missing' => (
      title: 'Sobreposição desativada',
      message:
          'A tela de bloqueio fica sem reforço se a acessibilidade cair. Reative "Sobrepor a '
          'outros apps" no aparelho da criança.',
    ),
    'notifications_disabled' => (
      title: 'Notificações desligadas no aparelho',
      message:
          'A criança não vê os avisos de tempo acabando. Reative as notificações do ParentaLynx '
          'no aparelho dela.',
    ),
    'battery_optimized' => (
      title: 'Economia de bateria ativa para o app',
      message:
          'O sistema pode encerrar o controle com a tela apagada. Libere o ParentaLynx da '
          'economia de bateria no aparelho da criança.',
    ),
    'suspend_failed' => (
      title: 'O sistema recusou suspender um app',
      message: 'O app continua bloqueado pela tela de bloqueio do ParentaLynx.',
    ),
    'policy_invalid' => (
      title: 'Regras novas não aplicadas',
      message:
          'O aparelho não conseguiu ler a versão atual das regras e continua com a anterior. '
          'Atualize o ParentaLynx no aparelho da criança.',
    ),
    'clock_untrusted' => (
      title: 'Relógio do aparelho não confirmado',
      message:
          'Sem a hora do servidor, o dia da cota pode ficar errado. Conecte o aparelho da '
          'criança à internet.',
    ),
    _ => (
      title: 'Problema na proteção',
      message:
          'O aparelho informou um problema que esta versão do app não reconhece. Atualize o '
          'ParentaLynx nos dois aparelhos.',
    ),
  };
}

/// Tempo sem sincronizar a partir do qual a conexao merece atencao (o mesmo do painel).
const Duration connectionStaleAfter = Duration(hours: 3);

/// Situacao de conexao de um aparelho ativo, para a etiqueta do painel, da lista e do detalhe.
///
/// [stale] diz se a falta de conexao merece atencao; sem ele, conta [connectionStaleAfter].
({String label, Tone tone, IconData icon}) connectionStatus(
  ChildDevice device, {
  required DateTime now,
  bool? stale,
}) {
  if (device.online) {
    return (label: 'Online', tone: Tone.success, icon: AppIcons.online);
  }
  final int? lastSync = device.lastSyncAt;
  if (lastSync == null) {
    return (label: 'Ainda não sincronizou', tone: Tone.warning, icon: AppIcons.syncProblem);
  }
  final String seen = formatRelativeMs(lastSync, now: now);
  final bool attention =
      stale ?? now.millisecondsSinceEpoch - lastSync > connectionStaleAfter.inMilliseconds;
  return (
    label: seen == 'agora' ? 'Visto agora há pouco' : 'Visto por último $seen',
    tone: attention ? Tone.warning : Tone.neutral,
    icon: AppIcons.offline,
  );
}

/// Ajuda do detalhe do aparelho, em perguntas e respostas.
const List<HelpTopic> deviceHelpTopics = <HelpTopic>[
  HelpTopic(
    title: 'O que é o nível de proteção?',
    body:
        'Depende de como o ParentaLynx foi instalado. Na instalação padrão, o controle funciona '
        'enquanto as permissões estiverem ativas e avisa você se alguma for desativada. Como '
        'dispositivo gerenciado, o próprio Android impõe o bloqueio.',
  ),
  HelpTopic(
    title: 'Como reativar uma permissão?',
    body:
        'No aparelho da criança, abra o ParentaLynx e toque em "Permissões do controle": o app '
        'leva até cada configuração do Android. O aparelho informa a mudança aqui na próxima '
        'sincronização.',
  ),
  HelpTopic(
    title: 'Para que serve o código de acesso offline?',
    body:
        'Para você se identificar no aparelho da criança quando ele estiver sem internet, por '
        'exemplo para liberar o uso por alguns minutos. O código muda a cada minuto.',
  ),
  HelpTopic(
    title: 'Desvincular ou apagar?',
    body:
        'Desvincular faz o aparelho deixar de ser controlado e mantém o histórico; dá para '
        'vincular de novo com um novo código. Apagar remove o aparelho, as regras e o histórico '
        'do servidor e não pode ser desfeito.',
  ),
];
