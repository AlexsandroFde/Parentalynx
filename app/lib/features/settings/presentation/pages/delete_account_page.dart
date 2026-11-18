import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/form_status.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../authentication/presentation/widgets/auth_widgets.dart';
import '../../domain/services/account_rules.dart';
import '../bloc/delete_account/delete_account_bloc.dart';

/// Exclusao da conta e de todos os dados, com senha e confirmacao digitada.
///
/// A palavra digitada e a confirmacao (mais forte que um dialogo): o botao so libera com a
/// senha e a palavra. Espera um [DeleteAccountBloc] acima na arvore. Com a conta excluida, a
/// sessao termina e o roteador leva as telas de conta.
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
    return BlocConsumer<DeleteAccountBloc, DeleteAccountState>(
      listenWhen: (DeleteAccountState previous, DeleteAccountState current) {
        return previous.status != current.status && current.status == FormStatus.succeeded;
      },
      listener: (BuildContext context, DeleteAccountState state) {
        Navigator.of(context).maybePop();
      },
      builder: (BuildContext context, DeleteAccountState state) {
        final bool busy = state.status != FormStatus.editing;
        final String? email = state.email;
        return AuthScaffold(
          icon: AppIcons.deleteForever,
          title: 'Excluir conta',
          subtitle: email == null
              ? 'Esta ação apaga tudo e não pode ser desfeita.'
              : 'A conta $email e tudo o que está nela serão apagados. Não pode ser desfeito.',
          children: <Widget>[
            const AppBanner(
              tone: Tone.danger,
              title: 'O que será apagado',
              message:
                  'A conta, todos os aparelhos vinculados, as regras, os relatórios, o histórico '
                  'de navegação e os alertas. Os aparelhos das crianças deixam de ser '
                  'controlados na próxima sincronização.',
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPasswordField(
              controller: _password,
              isRequired: true,
              enabled: !busy,
              errorText: state.error,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                // Redesenha o botao, que depende da senha digitada.
                setState(() {});
                context.read<DeleteAccountBloc>().add(const DeleteAccountPasswordEdited());
              },
              onSubmitted: (_) => focusNextAfterPassword(),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _word,
              label: 'Palavra de confirmação',
              isRequired: true,
              hint: DeleteAccountPage.confirmationWord,
              helper: 'Digite ${DeleteAccountPage.confirmationWord} para liberar a exclusão.',
              enabled: !busy,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_canSubmit) {
                  _submit();
                }
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            if (state.formError case final String formError) ...<Widget>[
              AppBanner(
                tone: Tone.danger,
                title: 'A conta não foi excluída',
                message: '$formError Nada foi apagado.',
                liveRegion: true,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppButton.danger(
              label: 'Excluir conta e todos os dados',
              busy: busy,
              expand: true,
              onPressed: _canSubmit ? _submit : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton.tertiary(
              label: 'Cancelar',
              expand: true,
              onPressed: busy ? null : () => Navigator.of(context).maybePop(),
            ),
          ],
        );
      },
    );
  }
}
