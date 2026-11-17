import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../data/elevation_api.dart';

/// Executa uma operacao administrativa. Se o servidor responder que a senha precisa ser
/// confirmada (`elevation_required`), pede a senha, eleva a sessao e repete a operacao.
///
/// Se a pessoa fechar o pedido de senha, lanca [CancelledFailure]. Use [guardedAction] quando
/// quiser o tratamento padrao de erros na interface.
Future<T> runElevated<T>(BuildContext context, WidgetRef ref, Future<T> Function() action) async {
  try {
    return await action();
  } on ApiFailure catch (failure) {
    if (!failure.isElevationRequired || !context.mounted) {
      rethrow;
    }
    final bool elevated = await showElevationDialog(context);
    if (!elevated) {
      throw const CancelledFailure();
    }
    return action();
  }
}

/// Executa uma operacao administrativa com elevacao e tratamento padrao de erro: mostra a
/// mensagem da falha e devolve nulo. Cancelamento nao mostra nada.
Future<T?> guardedAction<T>(
  BuildContext context,
  WidgetRef ref,
  Future<T> Function() action, {
  String? successMessage,
}) async {
  try {
    final T result = await runElevated<T>(context, ref, action);
    if (successMessage != null && context.mounted) {
      showAppSnackBar(context, successMessage, tone: Tone.success);
    }
    return result;
  } on CancelledFailure {
    return null;
  } on Object catch (error) {
    if (context.mounted) {
      showFailure(context, error);
    }
    return null;
  }
}

/// Pede a senha administrativa e eleva a sessao. Devolve verdadeiro se a senha foi aceita.
Future<bool> showElevationDialog(BuildContext context) async {
  final bool? result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => const _ElevationDialog(),
  );
  return result ?? false;
}

class _ElevationDialog extends ConsumerStatefulWidget {
  const _ElevationDialog();

  @override
  ConsumerState<_ElevationDialog> createState() => _ElevationDialogState();
}

class _ElevationDialogState extends ConsumerState<_ElevationDialog> {
  final TextEditingController _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Digite a senha administrativa.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(elevationApiProvider).elevate(_password.text);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = _messageFor(toFailure(error));
      });
    }
  }

  static String _messageFor(AppFailure failure) {
    if (failure is ApiFailure) {
      if (failure.code == 'invalid_credentials') {
        return 'Senha incorreta.';
      }
      final int? retry = failure.retryAfterSec;
      if (failure.isLocked && retry != null) {
        return 'Muitas tentativas. Tente de novo em ${formatMinutes((retry / 60).ceil())}.';
      }
    }
    return failure.message;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      icon: const Icon(Icons.lock_outline),
      title: const Text('Confirme sua senha'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Para alterar regras e dados, confirme a senha administrativa.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          PasswordField(
            controller: _password,
            autofocus: true,
            enabled: !_busy,
            errorText: _error,
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        BusyButton(label: 'Confirmar', busy: _busy, expand: false, onPressed: _confirm),
      ],
    );
  }
}
