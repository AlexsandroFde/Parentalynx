import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/security/password_policy.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../auth/domain/guardian_account.dart';
import '../../auth/presentation/auth_messages.dart';
import '../../auth/presentation/elevation.dart';
import '../../auth/presentation/recovery_key_page.dart';
import '../../auth/presentation/session_controller.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../data/api_account_repository.dart';

/// Conta do responsavel: nome, senha administrativa, chave de recuperacao e exclusao.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  Future<void> _editName(BuildContext context, WidgetRef ref, GuardianAccount account) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _NameDialog(initial: account.displayName),
    );
    if (name == null || name == account.displayName || !context.mounted) {
      return;
    }
    final GuardianAccount? updated = await guardedAction<GuardianAccount>(
      context,
      ref,
      () => ref.read(accountRepositoryProvider).updateProfile(displayName: name),
      successMessage: 'Nome alterado.',
    );
    if (updated != null) {
      ref.read(guardianSessionProvider.notifier).updateAccount(updated);
    }
  }

  Future<void> _newRecoveryKey(BuildContext context, WidgetRef ref) async {
    final String? password = await showPasswordPrompt(
      context,
      title: 'Gerar nova chave',
      message:
          'A chave de recuperação atual deixa de valer. Confirme a senha administrativa para '
          'gerar outra.',
      confirmLabel: 'Gerar',
    );
    if (password == null || !context.mounted) {
      return;
    }
    try {
      final String key = await ref.read(accountRepositoryProvider).regenerateRecoveryKey(password);
      if (!context.mounted) {
        return;
      }
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (BuildContext pageContext) => PopScope(
            canPop: false,
            child: RecoveryKeyView(recoveryKey: key, onDone: () => Navigator.of(pageContext).pop()),
          ),
        ),
      );
    } on Object catch (error) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          authFailureMessage(error, wrongCredentials: 'Senha incorreta.'),
          tone: Tone.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GuardianAccount? account = ref.watch(guardianAccountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Conta e senha')),
      body: account == null
          ? const LoadingView()
          : PageBody(
              children: <Widget>[
                SectionCard(
                  title: 'Seus dados',
                  padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Nome'),
                        subtitle: Text(
                          account.displayName.isEmpty ? 'Não informado' : account.displayName,
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _editName(context, ref, account),
                      ),
                      ListTile(
                        leading: const Icon(Icons.alternate_email),
                        title: const Text('E-mail'),
                        subtitle: Text(account.email),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionCard(
                  title: 'Senha administrativa',
                  subtitle:
                      'Protege as regras, os relatórios e a desvinculação no aparelho da '
                      'criança. Ao trocar, os outros aparelhos conectados à conta precisam '
                      'entrar de novo.',
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const ChangePasswordPage(),
                      ),
                    ),
                    icon: const Icon(Icons.password),
                    label: const Text('Trocar senha'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionCard(
                  title: 'Chave de recuperação',
                  subtitle:
                      'É a única forma de recuperar o acesso se você esquecer a senha. Se '
                      'perdeu a chave ou alguém a viu, gere outra.',
                  child: OutlinedButton.icon(
                    onPressed: () => _newRecoveryKey(context, ref),
                    icon: const Icon(Icons.key_outlined),
                    label: const Text('Gerar nova chave'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionCard(
                  title: 'Excluir conta',
                  subtitle:
                      'Apaga a conta, os aparelhos vinculados, as regras e todo o histórico. '
                      'Os aparelhos das crianças deixam de ser controlados.',
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const DeleteAccountPage(),
                      ),
                    ),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Excluir conta e dados'),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Pede a senha administrativa em um dialogo. Devolve a senha digitada ou nulo.
Future<String?> showPasswordPrompt(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return _PasswordPromptDialog(title: title, message: message, confirmLabel: confirmLabel);
    },
  );
}

class _PasswordPromptDialog extends StatefulWidget {
  const _PasswordPromptDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  State<_PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<_PasswordPromptDialog> {
  final TextEditingController _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Digite a senha administrativa.');
      return;
    }
    Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.message,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          PasswordField(
            controller: _password,
            autofocus: true,
            errorText: _error,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _name.text.trim();
    if (name.isEmpty || name.length > 60) {
      setState(() => _error = 'Informe um nome com até 60 caracteres.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seu nome'),
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

/// Troca da senha administrativa.
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _currentError;
  String? _nextError;
  String? _confirmError;
  String? _formError;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  PasswordCheck get _check {
    final GuardianAccount? account = ref.read(guardianAccountProvider);
    return PasswordPolicy.evaluate(
      _next.text,
      email: account?.email,
      displayName: account?.displayName,
    );
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final PasswordCheck check = _check;
    setState(() {
      _formError = null;
      _currentError = _current.text.isEmpty ? 'Digite a senha atual.' : null;
      _nextError = check.isAcceptable ? null : check.issues.first.message;
      _confirmError = _confirm.text == _next.text ? null : 'As senhas não são iguais.';
    });
    if (_currentError != null || _nextError != null || _confirmError != null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .changePassword(currentPassword: _current.text, newPassword: _next.text);
      if (mounted) {
        showAppSnackBar(context, 'Senha alterada.', tone: Tone.success);
        Navigator.of(context).pop();
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        if (isWeakPassword(error)) {
          _nextError = authFailureMessage(error);
        } else {
          _formError = authFailureMessage(error, wrongCredentials: 'A senha atual está incorreta.');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Trocar senha',
      subtitle: 'Os outros aparelhos conectados à conta precisam entrar de novo.',
      children: <Widget>[
        if (_formError != null) ...<Widget>[
          NoticeBanner(message: _formError!, tone: Tone.danger),
          const SizedBox(height: AppSpacing.lg),
        ],
        PasswordField(
          controller: _current,
          enabled: !_busy,
          label: 'Senha atual',
          errorText: _currentError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.lg),
        PasswordField(
          controller: _next,
          enabled: !_busy,
          label: 'Nova senha',
          errorText: _nextError,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.newPassword],
          onChanged: (_) => setState(() => _nextError = null),
        ),
        const SizedBox(height: AppSpacing.md),
        PasswordStrengthMeter(password: _next.text, check: _check),
        const SizedBox(height: AppSpacing.lg),
        PasswordField(
          controller: _confirm,
          enabled: !_busy,
          label: 'Repita a nova senha',
          errorText: _confirmError,
          autofillHints: const <String>[AutofillHints.newPassword],
          onChanged: (_) => setState(() => _confirmError = null),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.xl),
        BusyButton(label: 'Trocar senha', busy: _busy, onPressed: _submit),
      ],
    );
  }
}

/// Exclusao da conta e de todos os dados, com senha e confirmacao digitada.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  /// Palavra que a pessoa precisa digitar para confirmar.
  static const String confirmationWord = 'EXCLUIR';

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _word = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _word.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _password.text.isNotEmpty &&
        _word.text.trim().toUpperCase() == DeleteAccountPage.confirmationWord;
  }

  Future<void> _submit() async {
    if (_busy || !_canSubmit) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider).deleteAccount(_password.text);
      if (mounted) {
        Navigator.of(context).pop();
      }
      await ref.read(guardianSessionProvider.notifier).onAccountDeleted();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = authFailureMessage(error, wrongCredentials: 'Senha incorreta.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
          enabled: !_busy,
          errorText: _error,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _word,
          enabled: !_busy,
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
          onPressed: _canSubmit && !_busy ? _submit : null,
          child: _busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Excluir conta e todos os dados'),
        ),
      ],
    );
  }
}
