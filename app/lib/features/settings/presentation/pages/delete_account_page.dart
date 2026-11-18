import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../authentication/presentation/widgets/auth_widgets.dart';
import '../../domain/services/account_rules.dart';
import '../bloc/delete_account/delete_account_bloc.dart';

/// Exclusao da conta e de todos os dados, com senha e confirmacao digitada.
///
/// Espera um [DeleteAccountBloc] acima na arvore. Com a conta excluida, a sessao termina e o
/// roteador leva as telas de conta.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  /// Palavra que a pessoa precisa digitar para confirmar.
  static const String confirmationWord = AccountRules.deletionWord;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _word = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _word.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return AccountRules.canConfirmDeletion(password: _password.text, word: _word.text);
  }

  void _submit() {
    context.read<DeleteAccountBloc>().add(
      DeleteAccountSubmitted(password: _password.text, word: _word.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return BlocConsumer<DeleteAccountBloc, DeleteAccountState>(
      listenWhen: (DeleteAccountState previous, DeleteAccountState current) {
        return previous.status != current.status && current.status == FormStatus.succeeded;
      },
      listener: (BuildContext context, DeleteAccountState state) {
        Navigator.of(context).maybePop();
      },
      builder: (BuildContext context, DeleteAccountState state) {
        final bool busy = state.status != FormStatus.editing;
        return AuthScaffold(
          title: 'Excluir conta',
          subtitle: 'Esta ação apaga tudo e não pode ser desfeita.',
          children: <Widget>[
            const NoticeBanner(
              tone: Tone.danger,
              title: 'O que será apagado',
              message:
                  'A conta, todos os aparelhos vinculados, as regras, os relatórios, o histórico '
                  'de navegação e os alertas. Os aparelhos das crianças deixam de ser controlados '
                  'na próxima sincronização.',
            ),
            const SizedBox(height: AppSpacing.lg),
            PasswordField(
              controller: _password,
              enabled: !busy,
              errorText: state.error,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                // Redesenha o botao, que depende da senha digitada.
                setState(() {});
                context.read<DeleteAccountBloc>().add(const DeleteAccountPasswordEdited());
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _word,
              enabled: !busy,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Digite ${DeleteAccountPage.confirmationWord} para confirmar',
                prefixIcon: Icon(Icons.warning_amber_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: _canSubmit && !busy ? _submit : null,
              child: busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Excluir conta e todos os dados'),
            ),
          ],
        );
      },
    );
  }
}
