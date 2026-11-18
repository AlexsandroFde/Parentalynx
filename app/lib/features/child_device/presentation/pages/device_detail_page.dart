import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/services/share_service.dart';
import '../../../device_sync/presentation/widgets/policy_sync_status_view.dart';
import '../../domain/entities/child_device.dart';
import '../bloc/child_device/child_device_bloc.dart';
import '../bloc/offline_code/offline_code_bloc.dart';
import '../dialogs/rename_child_dialog.dart';
import '../texts/device_texts.dart';
import '../widgets/offline_code_sheet.dart';

/// Detalhe de um aparelho: de quem e, se as regras valem nele, o nivel de protecao, as
/// permissoes (com o que fazer quando falta alguma), o codigo de acesso offline, os dados e as
/// acoes de desvincular e apagar.
///
/// Espera um [ChildDeviceBloc] acima na arvore. [offlineCodeBloc] cria o BLoC da folha do
/// codigo offline a partir do segredo devolvido pelo servidor.
class DeviceDetailPage extends StatelessWidget {
  const DeviceDetailPage({required this.offlineCodeBloc, super.key});

  final OfflineCodeBloc Function(String secret) offlineCodeBloc;

  static bool _listenWhen(ChildDeviceState previous, ChildDeviceState current) {
    if (current is ChildDeviceRemoved) {
      return previous is! ChildDeviceRemoved;
    }
    return current is ChildDeviceLoaded &&
        (previous is! ChildDeviceLoaded || previous.action != current.action);
  }

  void _onChanged(BuildContext context, ChildDeviceState state) {
    if (state is ChildDeviceRemoved) {
      showAppSnackBar(context, 'Aparelho apagado.', tone: Tone.success);
      if (context.canPop()) {
        context.pop();
      }
      return;
    }
    if (state is! ChildDeviceLoaded) {
      return;
    }
    switch (state.action) {
      case ActionSucceeded(:final String? message):
        if (message != null) {
          showAppSnackBar(context, message, tone: Tone.success);
        }
        switch (state.outcome) {
          case ChildDeviceExportReady(:final String content):
            unawaited(_share(context, state.device, content));
          case ChildDeviceOfflineSecretReady(:final String secret):
            unawaited(_showOfflineCode(context, state.device, secret));
          case null:
            break;
        }
      case ActionFailed(:final failure):
        showFailure(context, failure);
      case ActionIdle() || ActionRunning():
        break;
    }
  }

  Future<void> _share(BuildContext context, ChildDevice device, String content) async {
    try {
      await context.read<ShareService>().shareTextFile(
        fileName: 'parentalynx-${device.today.isEmpty ? 'dados' : device.today}.json',
        content: content,
        mimeType: 'application/json',
        subject: 'Dados de ${device.displayName} no ParentaLynx',
      );
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> _showOfflineCode(BuildContext context, ChildDevice device, String secret) {
    return showAppSheet<void>(
      context,
      title: 'Código de acesso offline',
      subtitle:
          'No aparelho de ${device.displayName}, abra o ParentaLynx, toque em "Área do '
          'responsável" e escolha "Usar código de acesso".',
      builder: (BuildContext context) {
        return BlocProvider<OfflineCodeBloc>(
          create: (BuildContext context) =>
              offlineCodeBloc(secret)..add(const OfflineCodeStarted()),
          child: OfflineCodeSheet(device: device),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChildDeviceBloc, ChildDeviceState>(
      listenWhen: _listenWhen,
      listener: _onChanged,
      builder: (BuildContext context, ChildDeviceState state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Aparelho'),
            actions: const <Widget>[
              HelpButton(
                title: 'Aparelho',
                subtitle: 'Proteção, permissões, código offline e o que cada ação faz.',
                topics: deviceHelpTopics,
              ),
            ],
          ),
          body: StateSwitcher(
            child: switch (state) {
              ChildDeviceLoaded() => AppPageBody(
                key: const ValueKey<String>('aparelho'),
                children: _DetailSections(state: state).sections(context),
              ),
              ChildDeviceLoading() => const AppPageBody(
                key: ValueKey<String>('carregando'),
                children: <Widget>[
                  SkeletonPanel(height: 120),
                  SectionGap(),
                  SkeletonPanel(height: 220),
                  SectionGap(),
                  SkeletonListGroup(),
                ],
              ),
              ChildDeviceNotFound() || ChildDeviceRemoved() => EmptyState(
                key: const ValueKey<String>('nao-encontrado'),
                icon: AppIcons.deviceUnlinked,
                title: 'Aparelho não encontrado',
                message:
                    'Ele pode ter sido apagado por outro responsável. A lista de aparelhos '
                    'mostra os que continuam na conta.',
                actionLabel: 'Ver aparelhos',
                onAction: () => context.go(GuardianPaths.devices),
              ),
            },
          ),
        );
      },
    );
  }
}

/// Secoes do detalhe de um aparelho carregado, com as acoes que despacham eventos ao BLoC.
class _DetailSections {
  const _DetailSections({required this.state});

  final ChildDeviceLoaded state;

  ChildDevice get device => state.device;

  Future<void> _rename(BuildContext context) async {
    final ChildDeviceBloc bloc = context.read<ChildDeviceBloc>();
    final String? name = await showRenameChildDialog(context, initial: device.childName);
    if (name == null || name == device.childName) {
      return;
    }
    bloc.add(ChildDeviceRenameRequested(name));
  }

  Future<void> _revoke(BuildContext context) async {
    final ChildDeviceBloc bloc = context.read<ChildDeviceBloc>();
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Desvincular o aparelho de ${device.displayName}?',
      message:
          'Na próxima sincronização, o aparelho deixa de ser controlado: limites e bloqueios '
          'param de valer.',
      consequence: 'O histórico fica guardado. Para controlar de novo, vincule com um novo código.',
      confirmLabel: 'Desvincular',
      destructive: true,
      icon: AppIcons.unlink,
    );
    if (confirmed) {
      bloc.add(const ChildDeviceRevokeRequested());
    }
  }

  Future<void> _deleteData(BuildContext context) async {
    final ChildDeviceBloc bloc = context.read<ChildDeviceBloc>();
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Apagar o histórico?',
      message:
          'Sessões de uso, eventos, navegação e relatórios de ${device.displayName} são '
          'apagados do servidor. As regras e o vínculo continuam.',
      consequence: 'Esta ação não pode ser desfeita.',
      confirmLabel: 'Apagar histórico',
      destructive: true,
      icon: AppIcons.clearAll,
    );
    if (confirmed) {
      bloc.add(const ChildDeviceDataDeleteRequested());
    }
  }

  Future<void> _deleteDevice(BuildContext context) async {
    final ChildDeviceBloc bloc = context.read<ChildDeviceBloc>();
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Apagar ${device.displayName}?',
      message:
          'O aparelho, as regras e todo o histórico são apagados do servidor. Se o aparelho '
          'ainda estiver vinculado, ele deixa de ser controlado.',
      consequence: 'Esta ação não pode ser desfeita.',
      confirmLabel: 'Apagar tudo',
      destructive: true,
      icon: AppIcons.deleteForever,
    );
    if (confirmed) {
      bloc.add(const ChildDeviceDeleteRequested());
    }
  }

  List<Widget> sections(BuildContext context) {
    final bool busy = state.busy;
    final ChildDeviceTask? running = state.runningTask;
    final bool active = device.status == DeviceLinkStatus.active;
    final DateTime now = context.read<Clock>().now();
    final ChildDeviceBloc bloc = context.read<ChildDeviceBloc>();
    return <Widget>[
      _Header(
        device: device,
        now: now,
        renaming: running == ChildDeviceTask.rename,
        onRename: active && !busy ? () => _rename(context) : null,
      ),
      if (device.status == DeviceLinkStatus.pending) ...<Widget>[
        const SizedBox(height: AppSpacing.xl),
        AppBanner(
          icon: AppIcons.deviceRinging,
          title: 'Aguardando a sua aprovação',
          message: 'Confira o número de confirmação nos dois aparelhos e aprove o vínculo.',
          actionLabel: 'Ver pedido',
          onAction: () => context.push(GuardianPaths.pairing),
        ),
      ],
      if (device.status == DeviceLinkStatus.revoked) ...<Widget>[
        const SizedBox(height: AppSpacing.xl),
        AppBanner(
          tone: Tone.neutral,
          icon: AppIcons.unlink,
          title: 'Vínculo revogado',
          message:
              'Este aparelho não é mais controlado. O histórico continua guardado até você '
              'apagar. Para controlar de novo, gere um código de vinculação.',
          actionLabel: 'Vincular de novo',
          onAction: () => context.push(GuardianPaths.pairing),
        ),
      ],
      if (active) ...<Widget>[
        const SectionGap(),
        _Protection(mode: device.managementMode),
        const SectionGap(),
        _Permissions(device: device, now: now),
        const SectionGap(),
        AppSection(
          title: 'Código de acesso offline',
          subtitle:
              'Para você se identificar no aparelho de ${device.displayName} quando ele estiver '
              'sem internet, por exemplo para liberar o uso por alguns minutos.',
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.secondary(
              label: 'Mostrar código',
              icon: AppIcons.pinCode,
              busy: running == ChildDeviceTask.offlineCode,
              onPressed: busy ? null : () => bloc.add(const ChildDeviceOfflineCodeRequested()),
            ),
          ),
        ),
      ],
      const SectionGap(),
      AppSection(
        title: 'Dados deste aparelho',
        child: AppListGroup(
          children: <Widget>[
            _ActionRow(
              icon: AppIcons.download,
              title: 'Exportar dados',
              subtitle: 'Uma cópia em arquivo para guardar ou enviar.',
              running: running == ChildDeviceTask.export,
              onTap: busy ? null : () => bloc.add(const ChildDeviceExportRequested()),
            ),
            _ActionRow(
              icon: AppIcons.clearAll,
              title: 'Apagar histórico',
              subtitle: 'Uso, eventos e navegação. As regras continuam. Não pode ser desfeito.',
              destructive: true,
              running: running == ChildDeviceTask.deleteData,
              onTap: busy ? null : () => _deleteData(context),
            ),
          ],
        ),
      ),
      const SectionGap(),
      AppSection(
        title: 'Vínculo',
        child: AppListGroup(
          children: <Widget>[
            if (active)
              _ActionRow(
                icon: AppIcons.unlink,
                title: 'Desvincular aparelho',
                subtitle:
                    'As regras deixam de valer. O histórico fica guardado e dá para vincular '
                    'de novo.',
                destructive: true,
                running: running == ChildDeviceTask.revoke,
                onTap: busy ? null : () => _revoke(context),
              ),
            _ActionRow(
              icon: AppIcons.deleteForever,
              title: 'Apagar aparelho e histórico',
              subtitle: 'Apaga tudo deste aparelho no servidor. Não pode ser desfeito.',
              destructive: true,
              running: running == ChildDeviceTask.delete,
              onTap: busy ? null : () => _deleteDevice(context),
            ),
          ],
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.device,
    required this.now,
    required this.renaming,
    required this.onRename,
  });

  final ChildDevice device;
  final DateTime now;
  final bool renaming;
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final bool active = device.status == DeviceLinkStatus.active;
    final ({String label, Tone tone, IconData icon}) connection = connectionStatus(
      device,
      now: now,
    );
    final int? battery = device.snapshot?.batteryPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPageHeader(
          eyebrow: 'Aparelho de',
          title: device.displayName,
          subtitle: <String>[
            if (device.deviceName.isNotEmpty) device.deviceName,
            device.hardwareLabel,
          ].join(' · '),
          trailing: renaming
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SizedBox.square(
                    dimension: AppSizes.iconLg,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                )
              : active
              ? AppIconButton(
                  icon: AppIcons.edit,
                  tooltip: 'Trocar o nome',
                  variant: AppIconButtonVariant.tonal,
                  onPressed: onRename,
                )
              : null,
          bottomSpacing: AppSpacing.md,
        ),
        if (active) ...<Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              StatusBadge(label: connection.label, tone: connection.tone, icon: connection.icon),
              if (battery != null) StatusBadge(label: 'Bateria $battery%', icon: AppIcons.battery),
              if (device.appVersion.isNotEmpty)
                StatusBadge(label: 'App ${device.appVersion}', showIcon: false),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PolicySyncStatusView(status: device.policySync, now: now),
        ],
      ],
    );
  }
}

class _Protection extends StatelessWidget {
  const _Protection({required this.mode});

  final DeviceManagementMode mode;

  @override
  Widget build(BuildContext context) {
    final ManagementModeInfo info = ManagementModeInfo.of(mode);
    return AppSection(
      title: 'Nível de proteção',
      trailing: StatusBadge(
        label: mode.label,
        tone: mode.isSystemEnforced ? Tone.success : Tone.neutral,
        icon: mode.isSystemEnforced ? AppIcons.protectionGood : AppIcons.protection,
      ),
      child: AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(info.summary, style: context.text.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            Semantics(header: true, child: Text('O que funciona', style: context.text.titleSmall)),
            for (final String line in info.guaranteed)
              _Bullet(text: line, icon: AppIcons.success, tone: Tone.success),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text('O que não é garantido', style: context.text.titleSmall),
            ),
            for (final String line in info.notGuaranteed)
              _Bullet(text: line, icon: AppIcons.info, tone: Tone.warning),
            if (!mode.isSystemEnforced) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Para o próprio Android impor o bloqueio, o aparelho precisa ser configurado '
                'como dispositivo gerenciado (veja o guia de instalação).',
                style: context.text.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.icon, required this.tone});

  final String text;
  final IconData icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Icon(icon, size: AppSizes.iconSm, color: tone.foreground(context)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

/// Permissoes informadas pelo aparelho, separadas entre essenciais e de reforco. Quando falta
/// alguma, o aviso diz o efeito e como resolver no aparelho da crianca.
class _Permissions extends StatelessWidget {
  const _Permissions({required this.device, required this.now});

  final ChildDevice device;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final DeviceSnapshot? snapshot = device.snapshot;
    if (snapshot == null) {
      return const AppSection(
        title: 'Permissões no aparelho',
        child: AppPanel(
          child: EmptyState(
            compact: true,
            icon: AppIcons.pending,
            title: 'O aparelho ainda não sincronizou',
            message:
                'Abra o ParentaLynx no aparelho da criança e conclua a configuração. As '
                'permissões aparecem aqui assim que ele se conectar.',
          ),
        ),
      );
    }
    final List<PermissionLine> lines = PermissionLine.of(snapshot.permissions);
    final List<String> issues = snapshot.issues;
    final String fix =
        'Para resolver: no aparelho de ${device.displayName}, abra o ParentaLynx e toque em '
        '"Permissões do controle".';
    return AppSection(
      title: 'Permissões no aparelho',
      subtitle: 'Informado pelo aparelho ${formatRelativeMs(snapshot.reportedAt, now: now)}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!snapshot.enforcementActive || issues.isNotEmpty) ...<Widget>[
            AppBanner(
              tone: snapshot.enforcementActive ? Tone.warning : Tone.danger,
              icon: AppIcons.protectionWeak,
              title: issues.length == 1
                  ? describeIssue(issues.single).title
                  : !snapshot.enforcementActive && issues.isEmpty
                  ? 'Controle inativo no aparelho'
                  : '${issues.length} problemas na proteção',
              message: issues.length == 1
                  ? describeIssue(issues.single).message
                  : issues.isEmpty
                  ? 'O aparelho informou que as regras não estão sendo aplicadas. $fix'
                  : '${issues.map((String code) => describeIssue(code).title).join('; ')}. $fix',
              liveRegion: true,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppListGroup(
            footer: 'Essenciais: sem elas o controle não conta o tempo nem bloqueia apps.',
            children: <Widget>[
              for (final PermissionLine line in lines.where((PermissionLine l) => l.essential))
                _PermissionRow(line: line),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppListGroup(
            footer: 'Reforço: deixam o controle mais difícil de contornar.',
            children: <Widget>[
              for (final PermissionLine line in lines.where((PermissionLine l) => !l.essential))
                _PermissionRow(line: line),
            ],
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.line});

  final PermissionLine line;

  @override
  Widget build(BuildContext context) {
    final Tone tone = line.granted
        ? Tone.success
        : line.essential
        ? Tone.danger
        : Tone.neutral;
    return AppListRow(
      leading: AppIconTile(
        icon: line.granted ? AppIcons.success : AppIcons.removeCircle,
        tone: tone,
      ),
      title: line.label,
      subtitle: line.purpose,
      trailing: StatusBadge(
        label: line.granted ? 'Ativa' : 'Desativada',
        tone: tone,
        showIcon: false,
      ),
    );
  }
}

/// Linha de acao de uma lista: o que faz e a consequencia. As destrutivas usam o tom de erro e
/// pedem confirmacao; a linha mostra o andamento enquanto a acao roda.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.running,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool running;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AppListRow(
        leading: AppIconTile(icon: icon, tone: destructive ? Tone.danger : Tone.info),
        title: title,
        titleStyle: destructive
            ? context.text.bodyLarge?.copyWith(color: context.colors.danger)
            : null,
        subtitle: subtitle,
        trailing: running
            ? const SizedBox.square(
                dimension: AppSizes.iconMd,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : null,
        showChevron: !running,
        enabled: onTap != null || running,
        onTap: onTap,
      ),
    );
  }
}
