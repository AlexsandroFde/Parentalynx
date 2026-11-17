import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/json/json_reader.dart';
import '../../../../core/security/totp.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../auth/presentation/elevation.dart';
import '../../guardian_paths.dart';
import '../../shell/data/local_prefs.dart';
import '../../shell/data/share_service.dart';
import '../data/devices_repository.dart';
import '../domain/device.dart';
import 'device_texts.dart';
import 'devices_providers.dart';

/// Detalhe de um aparelho: identificacao, nivel de protecao, permissoes, codigo de acesso
/// offline, exportacao e as acoes de desvincular e apagar.
class DeviceDetailPage extends ConsumerStatefulWidget {
  const DeviceDetailPage({required this.deviceId, super.key});

  final String deviceId;

  @override
  ConsumerState<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends ConsumerState<DeviceDetailPage> {
  bool _busy = false;

  DevicesRepository get _repository => ref.read(devicesRepositoryProvider);

  Future<T?> _run<T>(Future<T> Function() action, {String? success}) async {
    setState(() => _busy = true);
    final T? result = await guardedAction<T>(context, ref, action, successMessage: success);
    if (mounted) {
      setState(() => _busy = false);
    }
    return result;
  }

  Future<void> _rename(Device device) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _RenameDialog(initial: device.childName),
    );
    if (name == null || !mounted || name == device.childName) {
      return;
    }
    final Device? updated = await _run<Device>(
      () => _repository.rename(device.id, childName: name),
      success: 'Nome alterado.',
    );
    if (updated != null) {
      ref.read(devicesProvider.notifier).replace(updated);
    }
  }

  Future<void> _showOfflineCode(Device device) async {
    final String? secret = await _run<String>(() => _repository.offlineSecret(device.id));
    if (secret == null || !mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => _OfflineCodeSheet(secret: secret, device: device),
    );
  }

  Future<void> _export(Device device) async {
    final JsonMap? data = await _run<JsonMap>(() => _repository.exportData(device.id));
    if (data == null || !mounted) {
      return;
    }
    try {
      await ref
          .read(shareServiceProvider)
          .shareTextFile(
            fileName: 'parentalynx-${device.today.isEmpty ? 'dados' : device.today}.json',
            content: const JsonEncoder.withIndent('  ').convert(data.raw),
            mimeType: 'application/json',
            subject: 'Dados de ${device.displayName} no ParentaLynx',
          );
    } on Object catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> _revoke(Device device) async {
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
    if (!confirmed || !mounted) {
      return;
    }
    final bool? done = await _run<bool>(() async {
      await _repository.revoke(device.id);
      return true;
    }, success: 'Vínculo revogado.');
    if (done ?? false) {
      await ref.read(devicesProvider.notifier).refresh();
    }
  }

  Future<void> _deleteData(Device device) async {
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
    if (!confirmed || !mounted) {
      return;
    }
    await _run<bool>(() async {
      await _repository.deleteData(device.id);
      return true;
    }, success: 'Histórico apagado.');
  }

  Future<void> _deleteDevice(Device device) async {
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
    if (!confirmed || !mounted) {
      return;
    }
    final bool? done = await _run<bool>(() async {
      await _repository.deleteDevice(device.id);
      return true;
    }, success: 'Aparelho apagado.');
    if (done ?? false) {
      await ref.read(devicesProvider.notifier).refresh();
      if (mounted && context.canPop()) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Device>> devices = ref.watch(devicesProvider);
    final Device? device = devices.value?.firstWhereOrNull(
      (Device item) => item.id == widget.deviceId,
    );
    return Scaffold(
      appBar: AppBar(title: Text(device?.displayName ?? 'Aparelho')),
      body: device == null
          ? (devices.isLoading
                ? const LoadingView()
                : const EmptyState(
                    icon: Icons.smartphone_outlined,
                    title: 'Aparelho não encontrado',
                    message: 'Ele pode ter sido apagado por outro responsável.',
                  ))
          : PageBody(children: _sections(device)),
    );
  }

  List<Widget> _sections(Device device) {
    final bool active = device.status == DeviceStatus.active;
    final DeviceState? state = device.state;
    return <Widget>[
      _HeaderCard(device: device, busy: _busy, onRename: active ? () => _rename(device) : null),
      const SizedBox(height: AppSpacing.lg),
      if (device.status == DeviceStatus.pending) ...<Widget>[
        NoticeBanner(
          icon: Icons.phonelink_ring_outlined,
          title: 'Aguardando a sua aprovação',
          message: 'Confira o número de confirmação e aprove o vínculo.',
          actionLabel: 'Ver pedido',
          onAction: () => context.push(GuardianPaths.pairing),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (device.status == DeviceStatus.revoked) ...<Widget>[
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
        _PermissionsCard(state: state),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Código de acesso offline',
          subtitle:
              'Para você se identificar no aparelho da criança quando ele estiver sem '
              'internet (liberar uso por alguns minutos ou desvincular).',
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _showOfflineCode(device),
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
              onPressed: _busy ? null : () => _export(device),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Exportar dados'),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _deleteData(device),
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
                onPressed: _busy ? null : () => _revoke(device),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            _DangerButton(
              icon: Icons.delete_forever_outlined,
              label: 'Apagar aparelho e histórico',
              onPressed: _busy ? null : () => _deleteDevice(device),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.device, required this.busy, this.onRename});

  final Device device;
  final bool busy;
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ({String label, Tone tone, IconData icon}) connection = connectionStatus(device);
    final bool active = device.status == DeviceStatus.active;
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
  const _PermissionsCard({required this.state});

  final DeviceState? state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DeviceState? current = state;
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
      subtitle: 'Informado pelo aparelho ${formatRelativeMs(current.reportedAt)}.',
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

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _name.text.trim();
    if (name.isEmpty || name.length > 40) {
      setState(() => _error = 'Informe um nome com até 40 caracteres.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nome da criança'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: 'Nome', errorText: _error),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Mostra o codigo de acesso offline do momento, com a contagem ate ele mudar.
class _OfflineCodeSheet extends ConsumerStatefulWidget {
  const _OfflineCodeSheet({required this.secret, required this.device});

  final String secret;
  final Device device;

  @override
  ConsumerState<_OfflineCodeSheet> createState() => _OfflineCodeSheetState();
}

class _OfflineCodeSheetState extends ConsumerState<_OfflineCodeSheet> {
  static const Totp _totp = Totp();

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int now = ref.read(guardianClockProvider)().millisecondsSinceEpoch;
    String code;
    try {
      code = _totp.generate(widget.secret, now);
    } on FormatException {
      code = '';
    }
    final int remaining = _totp.secondsRemaining(now);
    final String spaced = code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Código de acesso offline', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No aparelho de ${widget.device.displayName}, abra o ParentaLynx, toque em "Área '
            'do responsável" e escolha "Usar código de acesso".',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (code.isEmpty)
            const NoticeBanner(
              tone: Tone.danger,
              message: 'Não foi possível calcular o código para este aparelho.',
            )
          else ...<Widget>[
            Semantics(
              label: 'Código ${code.split('').join(' ')}',
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  spaced,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: remaining / _totp.stepSeconds, minHeight: 6),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Muda em $remaining s',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const NoticeBanner(
            tone: Tone.warning,
            message:
                'Não mostre este código para a criança. Ele vale por poucos minutos e depende '
                'de os dois aparelhos estarem com a hora certa.',
          ),
        ],
      ),
    );
  }
}
