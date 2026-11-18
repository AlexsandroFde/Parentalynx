import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/child_layout.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../bloc/child_device_status/child_device_status_bloc.dart';
import '../texts/transparency_content.dart';

/// Explica, em linguagem simples, o que o controle parental faz neste aparelho, o que ele
/// registra e o que ele nao ve.
///
/// Aparece logo depois da vinculacao ([setup] verdadeiro, com o botao de continuar) e fica
/// sempre acessivel pela tela inicial.
class TransparencyPage extends StatelessWidget {
  const TransparencyPage({required this.setup, super.key});

  final bool setup;

  @override
  Widget build(BuildContext context) {
    final String guardianName = context.select<ChildDeviceStatusBloc, String>(
      (ChildDeviceStatusBloc bloc) => bloc.state.statusOrNull?.guardianName ?? '',
    );
    final String guardian = guardianName.isEmpty ? 'Seu responsável' : guardianName;
    final StatusColors colors = StatusColors.of(context);
    return Scaffold(
      appBar: setup ? null : AppBar(title: const Text('Sobre o controle')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ChildPageBody(
                padding: EdgeInsets.fromLTRB(20, setup ? 28 : 8, 20, 24),
                children: <Widget>[
                  const ChildHeader(
                    icon: Icons.visibility_outlined,
                    title: 'O que este app faz',
                    message:
                        'Este aparelho usa o ${AppConstants.appName}, um app de controle '
                        'parental. Veja o que ele faz e o que ele não faz.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionCard(
                    title: 'Quem cuida das regras',
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person_outline,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            '$guardian é o responsável por este aparelho e é quem define as '
                            'regras.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SectionCard(
                    title: 'O que o responsável controla',
                    child: Column(
                      children: <Widget>[
                        for (final String item in TransparencyContent.controlled)
                          BulletLine(icon: Icons.tune_rounded, text: item),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SectionCard(
                    title: 'O que o responsável consegue ver',
                    child: Column(
                      children: <Widget>[
                        for (final String item in TransparencyContent.collected)
                          BulletLine(icon: Icons.visibility_outlined, text: item),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SectionCard(
                    title: 'O que este app NÃO vê',
                    subtitle: 'Ele não tem como acessar nada disto.',
                    child: Column(
                      children: <Widget>[
                        for (final String item in TransparencyContent.neverCollected)
                          BulletLine(icon: Icons.block_rounded, color: colors.success, text: item),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const NoticeBanner(
                    icon: Icons.shield_outlined,
                    title: 'Sempre à vista',
                    message: TransparencyContent.alwaysVisible,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const NoticeBanner(
                    tone: Tone.success,
                    icon: Icons.emergency_outlined,
                    title: 'Emergências',
                    message: TransparencyContent.emergency,
                  ),
                ],
              ),
            ),
            if (setup)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
                  child: BusyButton(
                    label: 'Entendi, continuar',
                    onPressed: () => context.go(ChildPaths.setupPermissions),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
