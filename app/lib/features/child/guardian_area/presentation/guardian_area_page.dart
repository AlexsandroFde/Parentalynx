import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../agent/domain/child_models.dart';
import '../../agent/presentation/child_session.dart';
import '../../child_paths.dart';
import '../../shared/child_widgets.dart';
import '../domain/admin_auth_texts.dart';
import 'guardian_area_controller.dart';

/// Area do responsavel no aparelho da crianca: autenticacao e operacoes administrativas.
class GuardianAreaPage extends ConsumerStatefulWidget {
  const GuardianAreaPage({super.key});

  @override
  ConsumerState<GuardianAreaPage> createState() => _GuardianAreaPageState();
}

class _GuardianAreaPageState extends ConsumerState<GuardianAreaPage> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _code = TextEditingController();
  String? _busyAction;

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  GuardianAreaController get _controller => ref.read(guardianAreaControllerProvider.notifier);

  Future<void> _submit(bool codeMode) async {
    FocusScope.of(context).unfocus();
    if (codeMode) {
      await _controller.verifyOfflineCode(_code.text);
    } else {
      await _controller.verifyPassword(_password.text);
    }
    if (mounted && ref.read(guardianAreaControllerProvider).unlocked) {
      _password.clear();
      _code.clear();
    }
  }

  /// Executa uma operacao administrativa mostrando o andamento e o resultado.
  Future<void> _run(String action, Future<void> Function() operation, {String? success}) async {
    if (_busyAction != null) {
      return;
    }
    setState(() => _busyAction = action);
    try {
      await operation();
      if (mounted && success != null) {
        showAppSnackBar(context, success, tone: Tone.success);
      }
    } on AppFailure catch (failure) {
      if (mounted) {
        showAppSnackBar(context, failure.message, tone: Tone.danger);
      }
    } finally {
      if (mounted) {
        setState(() => _busyAction = null);
      }
    }
  }

  Future<void> _unlink() async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Desvincular este aparelho?',
      message:
          'O controle parental deixa de valer aqui: os limites e os bloqueios são removidos. '
          'Para voltar a controlar este aparelho será preciso um novo código.',
      confirmLabel: 'Desvincular',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _run('unlink', () async {
      final bool done = await _controller.unlink();
      if (!done) {
        throw const UnexpectedFailure('Não foi possível desvincular agora. Tente de novo.');
      }
    });
  }

  Future<void> _releaseOwner() async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Deixar de gerenciar o aparelho?',
      message:
          'O aparelho deixa de ser um dispositivo gerenciado. A desinstalação volta a ser '
          'possível e o bloqueio passa a depender das permissões do controle.',
      confirmLabel: 'Deixar de gerenciar',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _run('owner', () async {
      final bool done = await _controller.releaseDeviceOwner();
      if (!done) {
        throw const UnexpectedFailure('O sistema não aceitou a mudança. Tente de novo.');
      }
    }, success: 'O aparelho deixou de ser gerenciado.');
  }

  Future<void> _removeAdmin() async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Desativar o administrador?',
      message: 'Sem o administrador, o app pode ser desinstalado direto pelas configurações.',
      confirmLabel: 'Desativar',
    );
    if (confirmed && mounted) {
      await _run('admin', _controller.removeDeviceAdmin, success: 'Administrador desativado.');
    }
  }

  void _leave() {
    _controller.lock();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(ChildPaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final GuardianAreaState state = ref.watch(guardianAreaControllerProvider);
    final ChildStatus? status = ref.watch(agentStatusProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Área do responsável')),
      body: SafeArea(
        child: state.unlocked
            ? _AdminView(
                status: status,
                busyAction: _busyAction,
                onGrant: (int minutes) => _run(
                  'grant$minutes',
                  () => _controller.grantOverride(minutes),
                  success: 'Uso liberado por ${formatMinutes(minutes)}.',
                ),
                onClearOverride: () =>
                    _run('clear', _controller.clearOverride, success: 'Liberação encerrada.'),
                onPermissions: () => context.push(ChildPaths.permissions),
                onRequestAdmin: () => _run('admin', _controller.requestDeviceAdmin),
                onRemoveAdmin: _removeAdmin,
                onReleaseOwner: _releaseOwner,
                onUnlink: _unlink,
                onLeave: _leave,
              )
            : _AuthView(
                state: state,
                password: _password,
                code: _code,
                guardianName: status?.guardianName ?? '',
                onSubmit: () => _submit(state.codeMode),
                onToggleMode: () => _controller.setCodeMode(enabled: !state.codeMode),
              ),
      ),
    );
  }
}

class _AuthView extends StatelessWidget {
  const _AuthView({
    required this.state,
    required this.password,
    required this.code,
    required this.guardianName,
    required this.onSubmit,
    required this.onToggleMode,
  });

  final GuardianAreaState state;
  final TextEditingController password;
  final TextEditingController code;
  final String guardianName;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final String who = guardianName.isEmpty ? 'o responsável' : guardianName;
    return ChildPageBody(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: <Widget>[
        ChildHeader(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Só para o responsável',
          message: 'Aqui $who pode liberar o uso, rever as permissões ou desvincular o aparelho.',
        ),
        const SizedBox(height: AppSpacing.xl),
        if (state.codeMode) ...<Widget>[
          TextField(
            controller: code,
            enabled: !state.verifying,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: offlineCodeLength,
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (String value) => onSubmit(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: 4),
            decoration: const InputDecoration(
              labelText: 'Código de acesso offline',
              counterText: '',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const NoticeBanner(
            title: 'Onde achar o código',
            message:
                'No aparelho do responsável, abra o ParentaLynx, entre em Aparelhos, escolha '
                'este aparelho e toque em "Código de acesso offline". O código tem 8 números '
                'e muda a cada minuto. Funciona sem internet.',
          ),
        ] else
          PasswordField(
            controller: password,
            enabled: !state.verifying,
            autofocus: true,
            onSubmitted: (String value) => onSubmit(),
          ),
        if (state.error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            liveRegion: true,
            child: NoticeBanner(message: state.error!, tone: Tone.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        BusyButton(
          label: state.codeMode ? 'Entrar com o código' : 'Entrar',
          busy: state.verifying,
          onPressed: onSubmit,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: state.verifying ? null : onToggleMode,
            child: Text(
              state.codeMode ? 'Usar a senha administrativa' : 'Usar o código de acesso offline',
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminView extends StatelessWidget {
  const _AdminView({
    required this.status,
    required this.busyAction,
    required this.onGrant,
    required this.onClearOverride,
    required this.onPermissions,
    required this.onRequestAdmin,
    required this.onRemoveAdmin,
    required this.onReleaseOwner,
    required this.onUnlink,
    required this.onLeave,
  });

  final ChildStatus? status;
  final String? busyAction;
  final ValueChanged<int> onGrant;
  final VoidCallback onClearOverride;
  final VoidCallback onPermissions;
  final VoidCallback onRequestAdmin;
  final VoidCallback onRemoveAdmin;
  final VoidCallback onReleaseOwner;
  final VoidCallback onUnlink;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ChildStatus? current = status;
    final bool busy = busyAction != null;
    final bool overrideActive = current?.localOverrideActive ?? false;
    final bool owner = current?.permissions.deviceOwner ?? false;
    final bool admin = current?.permissions.deviceAdmin ?? false;
    final TextStyle? muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ChildPageBody(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: <Widget>[
        const NoticeBanner(
          tone: Tone.success,
          icon: Icons.lock_open_rounded,
          message:
              'Acesso do responsável liberado. Ele vale por 5 minutos. Ao terminar, toque em '
              '"Sair da área do responsável".',
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Liberar o uso agora',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                overrideActive && current != null
                    ? 'O uso está liberado até ${formatClockMs(current.localOverrideUntilMs)}.'
                    : 'Libera o aparelho por alguns minutos, mesmo com o tempo esgotado ou em '
                          'horário de pausa. Funciona sem internet e fica registrado.',
                style: muted,
              ),
              const SizedBox(height: AppSpacing.md),
              if (overrideActive)
                OutlinedButton(
                  onPressed: busy ? null : onClearOverride,
                  child: const Text('Encerrar a liberação'),
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final int minutes in localOverrideOptions)
                      FilledButton.tonal(
                        onPressed: busy ? null : () => onGrant(minutes),
                        child: Text(formatMinutes(minutes)),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: 'Permissões do controle',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                current != null && current.needsAttention
                    ? 'Há permissões desligadas. O controle está incompleto.'
                    : 'Confira se o controle tem tudo de que precisa para funcionar.',
                style: muted,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: busy ? null : onPermissions,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Rever as permissões'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (owner)
          SectionCard(
            title: 'Dispositivo gerenciado',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Este aparelho é gerenciado pelo ParentaLynx: o Android impede abrir apps '
                  'bloqueados e desinstalar o controle. Para desinstalar o app é preciso '
                  'deixar de gerenciar antes.',
                  style: muted,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: busy ? null : onReleaseOwner,
                  child: const Text('Deixar de gerenciar este aparelho'),
                ),
              ],
            ),
          )
        else
          SectionCard(
            title: 'Administrador do dispositivo',
            trailing: StatusPill(
              label: admin ? 'Ativo' : 'Desativado',
              tone: admin ? Tone.success : Tone.neutral,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Reforço opcional. Com ele ativo, para desinstalar o app é preciso desativar '
                  'o administrador antes, e o responsável é avisado.',
                  style: muted,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: busy ? null : (admin ? onRemoveAdmin : onRequestAdmin),
                  child: Text(admin ? 'Desativar o administrador' : 'Ativar o administrador'),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: 'Desvincular este aparelho',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Remove o controle parental deste aparelho. Os relatórios já enviados '
                'continuam na conta do responsável.',
                style: muted,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: busy ? null : onUnlink,
                child: busyAction == 'unlink'
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Desvincular'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: TextButton.icon(
            onPressed: busy ? null : onLeave,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sair da área do responsável'),
          ),
        ),
      ],
    );
  }
}
