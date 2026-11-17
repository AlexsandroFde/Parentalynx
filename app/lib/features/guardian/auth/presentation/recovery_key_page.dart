import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../shell/data/share_service.dart';
import 'session_controller.dart';
import 'widgets/auth_widgets.dart';

/// Mostra a chave de recuperacao recem-gerada e so deixa continuar depois que a pessoa
/// confirma que guardou. A chave nao e mostrada de novo.
class RecoveryKeyPage extends ConsumerWidget {
  const RecoveryKeyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GuardianSession session = ref.watch(guardianSessionProvider);
    final String? key = session is GuardianReady ? session.pendingRecoveryKey : null;
    if (key == null) {
      // O roteador ja esta saindo desta tela.
      return const Scaffold(body: LoadingView());
    }
    return PopScope(
      canPop: false,
      child: RecoveryKeyView(
        recoveryKey: key,
        onDone: () => ref.read(guardianSessionProvider.notifier).acknowledgeRecoveryKey(),
      ),
    );
  }
}

/// Conteudo da tela da chave de recuperacao. Usado apos criar a conta, apos recuperar o
/// acesso e quando a chave e gerada de novo nas configuracoes.
class RecoveryKeyView extends ConsumerStatefulWidget {
  const RecoveryKeyView({required this.recoveryKey, required this.onDone, super.key});

  final String recoveryKey;
  final VoidCallback onDone;

  @override
  ConsumerState<RecoveryKeyView> createState() => _RecoveryKeyViewState();
}

class _RecoveryKeyViewState extends ConsumerState<RecoveryKeyView> {
  bool _saved = false;

  Future<void> _copy() async {
    await ref.read(shareServiceProvider).copy(widget.recoveryKey);
    if (mounted) {
      showAppSnackBar(context, 'Chave copiada.', tone: Tone.success);
    }
  }

  Future<void> _share() async {
    try {
      await ref
          .read(shareServiceProvider)
          .shareText(
            'Chave de recuperação do ParentaLynx: ${widget.recoveryKey}\n'
            'Guarde em um lugar seguro e não compartilhe com a criança.',
            subject: 'Chave de recuperação do ParentaLynx',
          );
    } on Object catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AuthScaffold(
      showAppBar: false,
      icon: Icons.key_outlined,
      title: 'Guarde a chave de recuperação',
      subtitle:
          'Se você esquecer a senha administrativa, esta chave é a única forma de recuperar '
          'o acesso. Ela não será mostrada de novo.',
      children: <Widget>[
        RecoveryKeyBox(recoveryKey: widget.recoveryKey),
        const SizedBox(height: AppSpacing.md),
        CopyShareButtons(onCopy: _copy, onShare: _share),
        const SizedBox(height: AppSpacing.lg),
        const NoticeBanner(
          tone: Tone.warning,
          title: 'Onde guardar',
          message:
              'Anote em papel ou salve em um gerenciador de senhas. Não deixe no aparelho '
              'da criança nem em um lugar que ela consiga ver.',
        ),
        const SizedBox(height: AppSpacing.md),
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            value: _saved,
            onChanged: (bool? value) => setState(() => _saved = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text('Guardei a chave em um lugar seguro', style: theme.textTheme.bodyLarge),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: _saved ? widget.onDone : null, child: const Text('Continuar')),
      ],
    );
  }
}
