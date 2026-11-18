import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/services/child_name_policy.dart';
import '../../domain/entities/link_request.dart';
import '../../domain/services/link_request_rules.dart';

/// Confirma a aprovacao de um pedido de vinculo. Devolve o nome da crianca, sem espacos nas
/// pontas, ou nulo quando a pessoa desiste.
///
/// Antes de aprovar, a pessoa ve de novo o aparelho e o numero de confirmacao e marca que o
/// mesmo numero aparece no aparelho da crianca: e o que garante que o pedido veio do aparelho
/// certo.
Future<String?> showApproveLinkDialog(BuildContext context, LinkRequest request) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => _ApproveLinkDialog(request: request),
  );
}

class _ApproveLinkDialog extends StatefulWidget {
  const _ApproveLinkDialog({required this.request});

  final LinkRequest request;

  @override
  State<_ApproveLinkDialog> createState() => _ApproveLinkDialogState();
}

class _ApproveLinkDialogState extends State<_ApproveLinkDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.request.childName);
  bool _sameNumber = false;
  String? _nameError;
  bool _showNumberError = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final String? nameError = LinkRequestRules.childNameError(_name.text);
    setState(() {
      _nameError = nameError;
      _showNumberError = !_sameNumber;
    });
    if (nameError != null || !_sameNumber) {
      return;
    }
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final LinkRequest request = widget.request;
    final String code = request.confirmCode ?? '';
    final String spaced = code.split('').join(' ');
    final String device = request.deviceName.isEmpty ? 'Aparelho sem nome' : request.deviceName;
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
                child: Text('Aprovar o vínculo?', style: context.text.headlineSmall),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                request.hardwareLabel.isEmpty ? device : '$device · ${request.hardwareLabel}',
                style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colors.surfaceMuted,
                  borderRadius: context.shapes.controlRadius,
                ),
                child: Padding(
                  padding: AppSpacing.panel,
                  child: Column(
                    children: <Widget>[
                      Text('Número de confirmação', style: context.text.labelLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Semantics(
                        label: 'Número de confirmação $spaced',
                        excludeSemantics: true,
                        child: Text(
                          spaced,
                          style: context.text.displaySmall?.copyWith(
                            fontFeatures: AppTypography.tabularFigures,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCheckboxRow(
                title: 'O mesmo número aparece no aparelho da criança',
                value: _sameNumber,
                onChanged: (bool value) => setState(() {
                  _sameNumber = value;
                  _showNumberError = false;
                }),
              ),
              if (_showNumberError)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Text(
                      'Confira o número no aparelho da criança. Se for diferente, cancele e '
                      'rejeite o pedido.',
                      style: context.text.bodySmall?.copyWith(color: context.colors.danger),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Nome da criança',
                controller: _name,
                isRequired: true,
                hint: 'Ana',
                helper:
                    'Aparece no painel e nos relatórios. Até ${ChildNamePolicy.maxLength} '
                    'caracteres.',
                errorText: _nameError,
                prefixIcon: AppIcons.child,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton.primary(label: 'Aprovar vínculo', expand: true, onPressed: _submit),
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
