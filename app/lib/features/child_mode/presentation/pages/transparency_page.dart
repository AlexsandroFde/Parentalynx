import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../shared/design_system/design_system.dart';
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
    return Scaffold(
      appBar: setup ? null : AppBar(title: const Text('Sobre o controle')),
      bottomNavigationBar: setup
          ? StickyActionBar(
              message: 'Depois vêm as permissões do controle.',
              child: AppButton.primary(
                label: 'Entendi, continuar',
                onPressed: () => context.go(ChildPaths.setupPermissions),
              ),
            )
          : null,
      body: SafeArea(
        child: ChildPageBody(
          children: <Widget>[
            if (setup) ...<Widget>[
              Text('Primeiros passos · 1 de 2'.toUpperCase(), style: context.textStyles.eyebrow),
              const SizedBox(height: AppSpacing.md),
            ],
            const ChildHeader(
              icon: AppIcons.privacy,
              title: 'O que este app faz',
              message:
                  'Este aparelho usa o ${AppConstants.appName}, um app de controle parental. Veja '
                  'o que ele faz e o que ele não vê.',
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPanel(
              child: Row(
                children: <Widget>[
                  InitialAvatar(name: guardian, size: AppSizes.avatarLg),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      '$guardian é o responsável por este aparelho e é quem define as regras.',
                      style: context.text.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
            const SectionGap(),
            const _BulletSection(
              title: 'O que o responsável controla',
              items: TransparencyContent.controlled,
              icon: AppIcons.rules,
              tone: Tone.info,
            ),
            const SectionGap(),
            const _BulletSection(
              title: 'O que o responsável consegue ver',
              items: TransparencyContent.collected,
              icon: AppIcons.show,
              tone: Tone.neutral,
            ),
            const SectionGap(),
            const _BulletSection(
              title: 'O que este app NÃO vê',
              subtitle: 'Ele não tem como acessar nada disto.',
              items: TransparencyContent.neverCollected,
              icon: AppIcons.hide,
              tone: Tone.success,
            ),
            const SectionGap(),
            const AppBanner(
              icon: AppIcons.protection,
              title: 'Sempre à vista',
              message: TransparencyContent.alwaysVisible,
            ),
            const SizedBox(height: AppSpacing.md),
            const AppBanner(
              tone: Tone.success,
              icon: AppIcons.emergency,
              title: 'Emergências',
              message: TransparencyContent.emergency,
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista curta de frases com o mesmo marcador, sob um titulo de secao.
class _BulletSection extends StatelessWidget {
  const _BulletSection({
    required this.title,
    required this.items,
    required this.icon,
    required this.tone,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<String> items;
  final IconData icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return AppSection(
      title: title,
      subtitle: subtitle,
      child: Column(
        children: <Widget>[
          for (final String item in items) BulletLine(icon: icon, tone: tone, text: item),
        ],
      ),
    );
  }
}
