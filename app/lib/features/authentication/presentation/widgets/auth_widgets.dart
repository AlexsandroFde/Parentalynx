import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../core/security/password_policy.dart';
import '../../../../shared/design_system/design_system.dart';

/// Estrutura comum das telas de conta: barra com voltar, cabecalho com o contexto e o
/// formulario em coluna rolavel na largura de formulario.
///
/// O formulario e construido inteiro (sem lista sob demanda): a ordem de leitura e de foco
/// fica previsivel e o preenchimento automatico enxerga todos os campos.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
    this.showAppBar = true,
    this.eyebrow,
    this.trailing,
    this.showBrand = false,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Icone em destaque acima do titulo (por exemplo, o cadeado do painel bloqueado).
  final IconData? icon;
  final List<Widget> children;

  /// Falso nas telas sem volta (bloqueio, chave de recuperacao).
  final bool showAppBar;

  /// Rotulo curto acima do titulo.
  final String? eyebrow;

  /// Acao de apoio da tela, como a ajuda. Fica na barra superior (ou ao lado do titulo nas
  /// telas sem barra), sem estreitar o texto do cabecalho.
  final Widget? trailing;

  /// Mostra a marca acima do titulo (telas de primeiro acesso).
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              actions: <Widget>[
                ?trailing,
                const SizedBox(width: AppSpacing.xs),
              ],
            )
          : null,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxFormWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                showAppBar ? AppSpacing.xs : AppSpacing.xxl,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (showBrand) ...<Widget>[
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: BrandLockup(),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                    if (icon != null) ...<Widget>[
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconMedallion(icon: icon!, tone: Tone.info),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    AppPageHeader(
                      eyebrow: eyebrow,
                      title: title,
                      subtitle: subtitle,
                      trailing: showAppBar ? null : trailing,
                    ),
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

/// Faz o "proximo" do teclado seguir para o proximo campo depois de um campo de senha.
///
/// O botao de mostrar a senha fica logo depois do campo na ordem de foco, entao o "proximo"
/// para nele e o teclado fecha. Chamado no `onSubmitted` do campo de senha, pula esse botao.
/// A troca de foco do teclado termina em uma microtarefa, por isso a conferencia e agendada.
void focusNextAfterPassword() {
  scheduleMicrotask(() {
    final FocusNode? node = FocusManager.instance.primaryFocus;
    if (node?.context?.findAncestorWidgetOfExactType<IconButton>() != null) {
      node!.nextFocus();
    }
  });
}

/// Indicador pequeno de operacao em andamento, para o lugar do complemento de uma linha.
class InlineProgress extends StatelessWidget {
  const InlineProgress({this.label = 'Em andamento', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: const SizedBox.square(
        dimension: AppSizes.iconMd,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      ),
    );
  }
}

/// Forca da senha com a lista de requisitos, visivel antes de a pessoa digitar.
///
/// Cada requisito mostra o estado em icone e texto (e o leitor de tela le "atendido" ou
/// "pendente"), nunca so em cor.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({required this.password, required this.check, super.key});

  final String password;
  final PasswordCheck check;

  @override
  Widget build(BuildContext context) {
    final bool empty = password.isEmpty;
    final Tone tone = empty
        ? Tone.neutral
        : switch (check.strength) {
            0 || 1 => Tone.danger,
            2 => Tone.warning,
            _ => Tone.success,
          };
    final Color color = empty ? context.colors.textSecondary : tone.foreground(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          empty ? 'A senha precisa ter:' : 'Força da senha: ${check.strengthLabel}',
          style: context.text.labelLarge?.copyWith(color: color),
        ),
        const SizedBox(height: AppSpacing.sm),
        UsageBar(fraction: empty ? 0 : (check.strength + 1) / 5, color: color),
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
    final Color color = met
        ? Tone.success.foreground(context)
        : problem
        ? Tone.danger.foreground(context)
        : context.colors.textSecondary;
    final IconData icon = met
        ? AppIcons.successFilled
        : problem
        ? AppIcons.error
        : AppIcons.radioOff;
    final String status = met
        ? 'atendido'
        : problem
        ? 'corrija'
        : 'pendente';
    return Semantics(
      label: '$label: $status',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Icon(icon, size: AppSizes.iconSm, color: color),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label, style: context.text.bodySmall?.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chave de recuperacao em destaque, selecionavel e com algarismos de largura fixa.
///
/// O leitor de tela soletra a chave em grupos, para quem anota ouvindo.
class RecoveryKeyBox extends StatelessWidget {
  const RecoveryKeyBox({required this.recoveryKey, super.key});

  final String recoveryKey;

  /// "R K, 7 H 2 K D, ...": cada caractere separado, grupos separados por virgula.
  String get _spelled {
    return recoveryKey.split('-').map((String group) => group.split('').join(' ')).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      child: Semantics(
        label: 'Chave de recuperação: $_spelled',
        excludeSemantics: true,
        child: Column(
          children: <Widget>[
            Text(
              'Chave de recuperação',
              textAlign: TextAlign.center,
              style: context.textStyles.eyebrow,
            ),
            const SizedBox(height: AppSpacing.md),
            SelectableText(
              recoveryKey,
              textAlign: TextAlign.center,
              style: context.text.titleLarge?.copyWith(
                fontFeatures: AppTypography.tabularFigures,
                letterSpacing: 1.6,
                height: 1.5,
              ),
            ),
          ],
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
    final Widget copy = AppButton.secondary(
      label: 'Copiar',
      icon: AppIcons.copy,
      expand: true,
      onPressed: onCopy,
    );
    final Widget share = AppButton.secondary(
      label: 'Compartilhar',
      icon: AppIcons.share,
      expand: true,
      onPressed: onShare,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 400) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              copy,
              const SizedBox(height: AppSpacing.sm),
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

/// Moldura dos dialogos com um campo (senha, nome), no mesmo padrao da confirmacao do Design
/// System: icone, titulo, explicacao, consequencia, o campo e as acoes empilhadas.
///
/// Enquanto [busy] o botao de confirmar fica ocupado e o de cancelar, inativo.
class FormDialogFrame extends StatelessWidget {
  const FormDialogFrame({
    required this.icon,
    required this.title,
    required this.message,
    required this.field,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.consequence,
    this.busy = false,
    this.tone = Tone.info,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget field;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  /// O que muda e nao volta atras, em destaque.
  final String? consequence;
  final bool busy;
  final Tone tone;

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
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconMedallion(
                  icon: icon,
                  tone: tone,
                  size: AppSizes.avatarLg - AppSpacing.sm,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(header: true, child: Text(title, style: context.text.headlineSmall)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary),
              ),
              if (consequence != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  consequence!,
                  style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              field,
              const SizedBox(height: AppSpacing.xl),
              AppButton.primary(
                label: confirmLabel,
                busy: busy,
                expand: true,
                onPressed: onConfirm,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton.tertiary(
                label: 'Cancelar',
                expand: true,
                onPressed: busy ? null : onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
