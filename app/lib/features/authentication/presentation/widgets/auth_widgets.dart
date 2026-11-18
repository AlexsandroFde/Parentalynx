import 'package:material_ui/material_ui.dart';

import '../../../../core/security/password_policy.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';

/// Estrutura comum das telas de conta: barra com voltar, titulo, texto de apoio e o
/// formulario em coluna rolavel de largura limitada.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
    this.showAppBar = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;

  /// Falso nas telas sem volta (bloqueio, chave de recuperacao).
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: showAppBar ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, showAppBar ? 4 : 32, 20, 24),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(icon, size: 28, color: theme.colorScheme.onPrimaryContainer),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Text(title, style: theme.textTheme.headlineSmall),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicador de forca da senha com a lista de requisitos.
///
/// Mostra o que falta em texto, nao so em cor, para quem nao distingue as cores.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({required this.password, required this.check, super.key});

  final String password;
  final PasswordCheck check;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Tone tone = switch (check.strength) {
      0 || 1 => Tone.danger,
      2 => Tone.warning,
      _ => Tone.success,
    };
    final Color color = tone.foreground(context);
    final bool empty = password.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: empty ? 0 : (check.strength + 1) / 5,
            minHeight: 6,
            color: color,
            semanticsLabel: 'Força da senha',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          empty ? 'Crie uma senha forte' : 'Força: ${check.strengthLabel}',
          style: theme.textTheme.labelLarge?.copyWith(
            color: empty ? theme.colorScheme.onSurfaceVariant : color,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _Requirement(
          met: !empty && !check.issues.contains(PasswordIssue.tooShort),
          label: 'Pelo menos 10 caracteres',
        ),
        _Requirement(
          met: !empty && !check.issues.contains(PasswordIssue.fewClasses),
          label: 'Três tipos entre minúsculas, maiúsculas, números e símbolos',
        ),
        for (final PasswordIssue issue in check.issues)
          if (issue != PasswordIssue.tooShort && issue != PasswordIssue.fewClasses && !empty)
            _Requirement(met: false, label: issue.message, problem: true),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.met, required this.label, this.problem = false});

  final bool met;
  final String label;

  /// Verdadeiro para um problema encontrado (em vez de um requisito ainda nao cumprido).
  final bool problem;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = met
        ? Tone.success.foreground(context)
        : problem
        ? Tone.danger.foreground(context)
        : theme.colorScheme.onSurfaceVariant;
    final IconData icon = met
        ? Icons.check_circle
        : problem
        ? Icons.error_outline
        : Icons.radio_button_unchecked;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: met || problem ? color : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Caixa com a chave de recuperacao em destaque, em fonte de largura fixa e selecionavel.
class RecoveryKeyBox extends StatelessWidget {
  const RecoveryKeyBox({required this.recoveryKey, super.key});

  final String recoveryKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Semantics(
        label: 'Chave de recuperação',
        child: SelectableText(
          recoveryKey,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            letterSpacing: 1.2,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

/// Botoes de copiar e compartilhar. Lado a lado em telas largas e empilhados em celulares,
/// para o rotulo nao quebrar em duas linhas.
class CopyShareButtons extends StatelessWidget {
  const CopyShareButtons({required this.onCopy, required this.onShare, super.key});

  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final Widget copy = OutlinedButton.icon(
      onPressed: onCopy,
      icon: const Icon(Icons.copy_outlined, size: 20),
      label: const Text('Copiar'),
    );
    final Widget share = OutlinedButton.icon(
      onPressed: onShare,
      icon: const Icon(Icons.share_outlined, size: 20),
      label: const Text('Compartilhar'),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 400) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              copy,
              const SizedBox(height: AppSpacing.md),
              share,
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: copy),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: share),
          ],
        );
      },
    );
  }
}
