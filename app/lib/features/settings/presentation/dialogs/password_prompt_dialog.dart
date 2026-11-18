import 'package:material_ui/material_ui.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../authentication/domain/services/credentials_policy.dart';

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
    final String? error = CredentialsPolicy.enteredPasswordError(_password.text);
    if (error != null) {
      setState(() => _error = error);
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
