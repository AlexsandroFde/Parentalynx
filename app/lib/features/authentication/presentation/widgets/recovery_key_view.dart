import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/services/share_service.dart';
import 'auth_widgets.dart';

/// Conteudo da tela da chave de recuperacao. Usado apos criar a conta, apos recuperar o
/// acesso e quando a chave e gerada de novo nas configuracoes.
///
/// So deixa continuar depois que a pessoa confirma que guardou a chave. Copia e compartilha
/// pelo [ShareService] entregue pela arvore de widgets.
class RecoveryKeyView extends StatefulWidget {
  const RecoveryKeyView({required this.recoveryKey, required this.onDone, this.eyebrow, super.key});

  final String recoveryKey;
  final VoidCallback onDone;

  /// Rotulo acima do titulo, com o que acabou de acontecer ("Nova chave gerada").
  final String? eyebrow;

  @override
  State<RecoveryKeyView> createState() => _RecoveryKeyViewState();
}

class _RecoveryKeyViewState extends State<RecoveryKeyView> {
  bool _saved = false;

  Future<void> _copy() async {
    await context.read<ShareService>().copy(widget.recoveryKey);
    if (mounted) {
      showAppSnackBar(context, 'Chave copiada.', tone: Tone.success);
    }
  }

  Future<void> _share() async {
    try {
      await context.read<ShareService>().shareText(
        'Chave de recuperação do ParentaLynx: ${widget.recoveryKey}\n'
        'Guarde em um lugar seguro e não compartilhe com a criança.',
        subject: 'Chave de recuperação do ParentaLynx',
      );
    } on Object {
      if (mounted) {
        showAppSnackBar(
          context,
          'Não foi possível abrir o compartilhamento. Copie a chave ou anote em papel.',
          tone: Tone.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showAppBar: false,
      icon: AppIcons.key,
      eyebrow: widget.eyebrow,
      title: 'Guarde a chave de recuperação',
      subtitle:
          'Se você esquecer a senha administrativa, esta chave é a única forma de recuperar '
          'o acesso. Ela não será mostrada de novo.',
      children: <Widget>[
        RecoveryKeyBox(recoveryKey: widget.recoveryKey),
        const SizedBox(height: AppSpacing.md),
        CopyShareButtons(onCopy: _copy, onShare: _share),
        const SizedBox(height: AppSpacing.xl),
        const AppBanner(
          tone: Tone.warning,
          title: 'Onde guardar',
          message:
              'Anote em papel ou salve em um gerenciador de senhas. Não deixe no aparelho da '
              'criança nem em um lugar que ela consiga ver.',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppListGroup(
          children: <Widget>[
            AppCheckboxRow(
              title: 'Guardei a chave em um lugar seguro',
              // Explica por que "Continuar" so libera depois desta confirmacao.
              subtitle: 'Necessário para continuar. Sem a chave, não há como recuperar a conta.',
              value: _saved,
              onChanged: (bool value) => setState(() => _saved = value),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton.primary(
          label: 'Continuar',
          expand: true,
          onPressed: _saved ? widget.onDone : null,
        ),
      ],
    );
  }
}
