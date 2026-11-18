import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/services/share_service.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../domain/entities/child_device.dart';
import '../bloc/child_device/child_device_bloc.dart';
import '../bloc/offline_code/offline_code_bloc.dart';
import '../dialogs/rename_child_dialog.dart';
import '../texts/device_texts.dart';
import '../widgets/offline_code_sheet.dart';

/// Detalhe de um aparelho: identificacao, nivel de protecao, permissoes, codigo de acesso
/// offline, exportacao e as acoes de desvincular e apagar.
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
        final ChildDevice? device = state is ChildDeviceLoaded ? state.device : null;
        return Scaffold(
          appBar: AppBar(title: Text(device?.displayName ?? 'Aparelho')),
          body: switch (state) {
            ChildDeviceLoaded() => PageBody(
              children: _DetailSections(state: state).sections(context),
            ),
            ChildDeviceLoading() => const LoadingView(),
            ChildDeviceNotFound() || ChildDeviceRemoved() => const EmptyState(
              icon: Icons.smartphone_outlined,
              title: 'Aparelho não encontrado',
              message: 'Ele pode ter sido apagado por outro responsável.',
            ),
          },
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
    final bool confirmed = await confirmAction(
      context,
      title: 'Desvincular ${device.displayName}?',
      message:
          'O aparelho deixa de ser controlado na próxima vez que sincronizar: limites e '
          'bloqueios param de valer. O histórico fica guardado e você pode vincular de novo '
          'com um novo código.',
      confirmLabel: 'Desvincular',
      destructive: true,
    );
    if (confirmed) {
      bloc.add(const ChildDeviceRevokeRequested());
    }
  }

  Future<void> _deleteData(BuildContext context) async {
    final ChildDeviceBloc bloc = context.read<ChildDeviceBloc>();
    final bool confirmed = await confirmAction(
      context,
      title: 'Apagar o histórico?',
      message:
          'Sessões de uso, eventos, navegação e relatórios de ${device.displayName} são '
          'apagados do servidor. As regras e o vínculo continuam. Esta ação não pode ser '
          'desfeita.',
      confirmLabel: 'Apagar histórico',
      destructive: true,
    );
    if (confirmed) {
      bloc.add(const ChildDeviceDataDeleteRequested());
    }
  }

  Future<void> _deleteDevice(BuildContext context) async {
    final ChildDeviceBloc bloc = context.read<ChildDeviceBloc>();
    final bool confirmed = await confirmAction(
      context,
      title: 'Apagar ${device.displayName}?',
      message:
          'O aparelho, as regras e todo o histórico são apagados do servidor. Se o aparelho '
          'ainda estiver vinculado, ele deixa de ser controlado. Esta ação não pode ser '
          'desfeita.',
      confirmLabel: 'Apagar tudo',
      destructive: true,
    );
    if (confirmed) {
      bloc.add(const ChildDeviceDeleteRequested());
    }
  }

  List<Widget> sections(BuildContext context) {
    final bool busy = state.busy;
    final bool active = device.status == DeviceLinkStatus.active;
    final DeviceSnapshot? snapshot = device.snapshot;
    final DateTime now = context.read<Clock>().now();
    return <Widget>[
      _HeaderCard(
        device: device,
        busy: busy,
        now: now,
        onRename: active ? () => _rename(context) : null,
      ),
      const SizedBox(height: AppSpacing.lg),
      if (device.status == DeviceLinkStatus.pending) ...<Widget>[
        NoticeBanner(
          icon: Icons.phonelink_ring_outlined,
          title: 'Aguardando a sua aprovação',
          message: 'Confira o número de confirmação e aprove o vínculo.',
          actionLabel: 'Ver pedido',
          onAction: () => context.push(GuardianPaths.pairing),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (device.status == DeviceLinkStatus.revoked) ...<Widget>[
        const NoticeBanner(
          tone: Tone.neutral,
          icon: Icons.link_off,
          title: 'Vínculo revogado',
          message:
              'Este aparelho não é mais controlado. O histórico continua guardado até você '
              'apagar. Para controlar de novo, gere um código de vinculação.',
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (active) ...<Widget>[
        _ProtectionCard(mode: device.managementMode),
        const SizedBox(height: AppSpacing.lg),
        _PermissionsCard(snapshot: snapshot, now: now),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Código de acesso offline',
          subtitle:
              'Para você se identificar no aparelho da criança quando ele estiver sem '
              'internet (liberar uso por alguns minutos ou desvincular).',
          child: OutlinedButton.icon(
            onPressed: busy
                ? null
                : () =>
                      context.read<ChildDeviceBloc>().add(const ChildDeviceOfflineCodeRequested()),
            icon: const Icon(Icons.pin_outlined),
            label: const Text('Mostrar código'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      SectionCard(
        title: 'Dados deste aparelho',
        subtitle: 'Exportar uma cópia ou apagar o que está guardado no servidor.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => context.read<ChildDeviceBloc>().add(const ChildDeviceExportRequested()),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Exportar dados'),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: busy ? null : () => _deleteData(context),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Apagar histórico'),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      SectionCard(
        title: 'Zona de risco',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (active) ...<Widget>[
              _DangerButton(
                icon: Icons.link_off,
                label: 'Desvincular aparelho',
                onPressed: busy ? null : () => _revoke(context),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            _DangerButton(
              icon: Icons.delete_forever_outlined,
              label: 'Apagar aparelho e histórico',
              onPressed: busy ? null : () => _deleteDevice(context),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.device, required this.busy, required this.now, this.onRename});

  final ChildDevice device;
  final bool busy;
  final DateTime now;
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ({String label, Tone tone, IconData icon}) connection = connectionStatus(
      device,
      now: now,
    );
    final bool active = device.status == DeviceLinkStatus.active;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(device.displayName, style: theme.textTheme.headlineSmall)),
                if (onRename != null)
                  IconButton(
                    tooltip: 'Trocar o nome',
                    onPressed: busy ? null : onRename,
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
            Text(
              <String>[
                if (device.deviceName.isNotEmpty) device.deviceName,
                device.hardwareLabel,
              ].join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (active) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  StatusPill(label: connection.label, tone: connection.tone, icon: connection.icon),
                  StatusPill(
                    label: device.policyPending
                        ? 'Regras aguardando o aparelho'
                        : 'Regras aplicadas',
                    tone: device.policyPending ? Tone.warning : Tone.success,
                    icon: device.policyPending ? Icons.schedule : Icons.check_circle_outline,
                  ),
                  if (device.appVersion.isNotEmpty) StatusPill(label: 'App ${device.appVersion}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProtectionCard extends StatelessWidget {
  const _ProtectionCard({required this.mode});

  final DeviceManagementMode mode;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ManagementModeInfo info = ManagementModeInfo.of(mode);
    return SectionCard(
      title: 'Nível de proteção',
      trailing: StatusPill(
        label: mode.label,
        tone: mode.isSystemEnforced ? Tone.success : Tone.info,
        icon: mode.isSystemEnforced ? Icons.verified_user_outlined : Icons.shield_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(info.summary, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Text('O que funciona', style: theme.textTheme.labelLarge),
          for (final String line in info.guaranteed)
            _Bullet(text: line, icon: Icons.check_circle_outline, tone: Tone.success),
          const SizedBox(height: AppSpacing.md),
          Text('O que não é garantido', style: theme.textTheme.labelLarge),
          for (final String line in info.notGuaranteed)
            _Bullet(text: line, icon: Icons.info_outline, tone: Tone.warning),
          if (!mode.isSystemEnforced) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Para bloqueio imposto pelo próprio Android, o aparelho precisa ser configurado '
              'como dispositivo gerenciado (ver a documentação de instalação).',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
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
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: tone.foreground(context)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({required this.snapshot, required this.now});

  final DeviceSnapshot? snapshot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DeviceSnapshot? current = snapshot;
    if (current == null) {
      return const SectionCard(
        title: 'Permissões no aparelho',
        child: NoticeBanner(
          tone: Tone.warning,
          message:
              'O aparelho ainda não sincronizou. Abra o ParentaLynx no aparelho da criança '
              'e conclua a configuração.',
        ),
      );
    }
    final List<PermissionLine> lines = PermissionLine.of(current.permissions);
    return SectionCard(
      title: 'Permissões no aparelho',
      subtitle: 'Informado pelo aparelho ${formatRelativeMs(current.reportedAt, now: now)}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String issue in current.issues)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: NoticeBanner(tone: Tone.warning, message: issueLabel(issue)),
            ),
          for (final PermissionLine line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    line.granted
                        ? Icons.check_circle
                        : line.essential
                        ? Icons.error
                        : Icons.remove_circle_outline,
                    size: 20,
                    color: line.granted
                        ? Tone.success.foreground(context)
                        : line.essential
                        ? Tone.danger.foreground(context)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${line.label}: ${line.granted ? 'ativa' : 'desativada'}',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          line.purpose,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.error;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
