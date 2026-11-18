import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../domain/services/child_name_policy.dart';

/// Pede o novo nome da crianca. Devolve o nome aceito pela regra, ou nulo se a pessoa
/// desistiu.
Future<String?> showRenameChildDialog(BuildContext context, {required String initial}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => _RenameDialog(initial: initial),
  );
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
    final String? error = ChildNamePolicy.error(_name.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxFormWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text('Nome da criança', style: context.text.headlineSmall),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'O nome aparece no painel, nas regras e nos relatórios.',
                style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                label: 'Nome',
                controller: _name,
                isRequired: true,
                autofocus: true,
                helper: 'Até ${ChildNamePolicy.maxLength} caracteres.',
                errorText: _error,
                prefixIcon: AppIcons.child,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton.primary(label: 'Salvar', expand: true, onPressed: _submit),
              const SizedBox(height: AppSpacing.sm),
              AppButton.tertiary(
                label: 'Cancelar',
                expand: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
