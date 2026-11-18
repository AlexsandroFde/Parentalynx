import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../../authentication/presentation/widgets/auth_widgets.dart';
import '../../domain/services/account_rules.dart';

/// Pede o nome de exibicao. Devolve o nome digitado, sem espacos nas pontas, ou nulo.
Future<String?> showDisplayNameDialog(BuildContext context, {required String initial}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => _DisplayNameDialog(initial: initial),
  );
}

class _DisplayNameDialog extends StatefulWidget {
  const _DisplayNameDialog({required this.initial});

  final String initial;

  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final String? error = AccountRules.displayNameError(_name.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return FormDialogFrame(
      icon: AppIcons.person,
      title: 'Seu nome',
      message: 'É o nome da conta da família, mostrado no topo da aba Mais.',
      confirmLabel: 'Salvar',
      onConfirm: _submit,
      onCancel: () => Navigator.of(context).pop(),
      field: AppTextField(
        controller: _name,
        label: 'Nome',
        isRequired: true,
        helper: 'Até ${AccountRules.maxDisplayNameLength} caracteres.',
        errorText: _error,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onChanged: (_) {
          if (_error != null) {
            setState(() => _error = null);
          }
        },
        onSubmitted: (_) => _submit(),
      ),
    );
  }
}
