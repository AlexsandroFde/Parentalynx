import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/shared/design_system/design_system.dart';
import 'package:parentalynx/shared/theme/app_frame.dart';

import '../../support/test_app.dart';

/// Catalogo do Design System: cada pagina mostra um grupo de componentes nos temas claro e
/// escuro. As capturas servem de referencia visual e de documentacao
/// (`docs/design/design-system.md`).
void main() {
  Future<void> pumpCatalog(
    WidgetTester tester,
    Widget page, {
    required Brightness brightness,
    double height = 1500,
  }) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = Size(phoneSize.width, height) * 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
        locale: appLocale,
        supportedLocales: const <Locale>[appLocale],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: wrapAppContent,
        home: page,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  const Map<String, Widget> pages = <String, Widget>{
    'fundamentos': _FoundationsPage(),
    'acoes': _ActionsPage(),
    'conteudo': _ContentPage(),
    'retorno': _FeedbackPage(),
    'crianca': AppExperienceScope(experience: AppExperience.child, child: _ChildPage()),
  };

  for (final MapEntry<String, Widget> page in pages.entries) {
    for (final Brightness brightness in Brightness.values) {
      final String theme = brightness == Brightness.light ? 'claro' : 'escuro';
      testWidgets('catalogo ${page.key} ($theme)', tags: 'screenshot', (WidgetTester tester) async {
        await pumpCatalog(tester, page.value, brightness: brightness);
        await expectScreenshot(tester, 'ds_${page.key}_$theme');
      });
    }
  }

  testWidgets('os componentes seguem as diretrizes de acessibilidade', (WidgetTester tester) async {
    for (final Widget page in pages.values) {
      await pumpCatalog(tester, page, brightness: Brightness.light, height: 3200);
      await expectAccessible(tester);
    }
  });

  for (final MapEntry<String, Widget> page in pages.entries) {
    testWidgets('catalogo ${page.key} funciona com a fonte no maior tamanho', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpCatalog(tester, page.value, brightness: Brightness.light, height: 6000);
      expect(tester.takeException(), isNull);
    });
  }
}

class _CatalogScaffold extends StatelessWidget {
  const _CatalogScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AppPageBody(children: children),
    );
  }
}

class _FoundationsPage extends StatelessWidget {
  const _FoundationsPage();

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    Widget swatch(String name, Color color, Color on) {
      return Container(
        width: 108,
        height: 64,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(color: color, borderRadius: context.shapes.controlRadius),
        alignment: Alignment.bottomLeft,
        child: Text(name, style: context.text.labelMedium?.copyWith(color: on)),
      );
    }

    return _CatalogScaffold(
      title: 'Fundamentos',
      children: <Widget>[
        const Row(children: <Widget>[BrandLockup(markSize: 48), Spacer(), BrandMark(size: 32)]),
        const SectionGap(),
        Text('APARELHO DE JOÃO', style: context.textStyles.eyebrow),
        Text('Regras de João', style: context.text.headlineMedium),
        Text('Tempo de hoje', style: context.text.titleLarge),
        Text('Mais usados hoje', style: context.text.titleMedium),
        Text(
          'O tempo recomeça amanhã às 00:00. Ligações de emergência continuam liberadas.',
          style: context.text.bodyLarge,
        ),
        Text('Atualizado há 2 min', style: context.text.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: AppSpacing.md,
          children: <Widget>[
            Text('1h 20min', style: context.textStyles.metricLarge),
            Text('restam hoje', style: context.text.bodyMedium),
          ],
        ),
        const SectionGap(),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            swatch('Marca', c.primary, c.onPrimary),
            swatch('Destaque', c.primaryContainer, c.onPrimaryContainer),
            swatch('Fundo', c.canvas, c.textPrimary),
            swatch('Superfície', c.surface, c.textPrimary),
            swatch('Apoio', c.surfaceMuted, c.textPrimary),
            swatch('Permitido', c.successContainer, c.onSuccessContainer),
            swatch('Atenção', c.warningContainer, c.onWarningContainer),
            swatch('Erro', c.dangerContainer, c.onDangerContainer),
            swatch('Descanso', c.restContainer, c.onRestContainer),
          ],
        ),
        const SectionGap(),
        const Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            Icon(AppIcons.dailyLimit),
            Icon(AppIcons.allowedHours),
            Icon(AppIcons.bedtime),
            Icon(AppIcons.apps),
            Icon(AppIcons.blocked),
            Icon(AppIcons.exception),
            Icon(AppIcons.web),
            Icon(AppIcons.protection),
            Icon(AppIcons.device),
            Icon(AppIcons.sync),
            Icon(AppIcons.extraTime),
            Icon(AppIcons.alerts),
          ],
        ),
      ],
    );
  }
}

class _ActionsPage extends StatelessWidget {
  const _ActionsPage();

  @override
  Widget build(BuildContext context) {
    return _CatalogScaffold(
      title: 'Ações e campos',
      children: <Widget>[
        AppButton.primary(label: 'Salvar regras', onPressed: () {}, expand: true),
        const SizedBox(height: AppSpacing.sm),
        AppButton.secondary(
          label: 'Pedir mais tempo',
          icon: AppIcons.extraTime,
          onPressed: () {},
          expand: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton.primary(label: 'Salvando', onPressed: () {}, busy: true, expand: true),
        const SizedBox(height: AppSpacing.sm),
        const AppButton.primary(label: 'Indisponível', onPressed: null, expand: true),
        const SizedBox(height: AppSpacing.sm),
        AppButton.danger(label: 'Desvincular aparelho', onPressed: () {}, expand: true),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            AppButton.secondary(label: '+ 15 min', onPressed: () {}, size: AppButtonSize.compact),
            AppButton.secondary(label: '+ 30 min', onPressed: () {}, size: AppButtonSize.compact),
            AppButton.tertiary(label: 'Ver todos', onPressed: () {}, size: AppButtonSize.compact),
            AppIconButton(icon: AppIcons.refresh, tooltip: 'Atualizar', onPressed: () {}),
            AppIconButton(
              icon: AppIcons.edit,
              tooltip: 'Editar',
              variant: AppIconButtonVariant.tonal,
              onPressed: () {},
            ),
          ],
        ),
        const SectionGap(),
        const AppTextField(
          label: 'E-mail',
          hint: 'maria@exemplo.com',
          isRequired: true,
          prefixIcon: AppIcons.email,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppPasswordField(
          controller: TextEditingController(text: 'curta'),
          isRequired: true,
          helper: 'Mínimo de 10 caracteres, com letras e números.',
          errorText: 'A senha precisa ter pelo menos 10 caracteres.',
        ),
        const SectionGap(),
        AppSection(
          title: 'Limite por dia',
          subtitle: 'Escolha um valor pronto ou defina outro.',
          child: AppChoiceChips<int>(
            choices: const <AppChoice<int>>[
              AppChoice<int>(value: 60, label: '1h'),
              AppChoice<int>(value: 120, label: '2h'),
              AppChoice<int>(value: 150, label: '2h 30min'),
              AppChoice<int>(value: 180, label: '3h'),
            ],
            selected: 150,
            onSelected: (_) {},
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSegmentedControl<int>(
          segments: const <AppChoice<int>>[
            AppChoice<int>(value: 0, label: 'Dia'),
            AppChoice<int>(value: 1, label: '7 dias'),
            AppChoice<int>(value: 2, label: '30 dias'),
          ],
          selected: 1,
          onChanged: (_) {},
        ),
        const SectionGap(),
        AppListGroup(
          footer: 'Os avisos chegam como notificação neste celular.',
          children: <Widget>[
            AppSwitchRow(
              title: 'Pouco tempo restante',
              subtitle: 'Quando faltarem 10 minutos',
              icon: AppIcons.timeRunningOut,
              tone: Tone.warning,
              value: true,
              onChanged: (_) {},
            ),
            AppSwitchRow(
              title: 'App novo instalado',
              icon: AppIcons.newApp,
              value: false,
              onChanged: (_) {},
            ),
          ],
        ),
      ],
    );
  }
}

class _ContentPage extends StatelessWidget {
  const _ContentPage();

  @override
  Widget build(BuildContext context) {
    return _CatalogScaffold(
      title: 'Conteúdo',
      children: <Widget>[
        const AppPageHeader(
          eyebrow: 'Hoje',
          title: 'João',
          subtitle: 'motorola moto g54 · Android 14',
          trailing: InitialAvatar(name: 'João', size: AppSizes.avatarLg),
        ),
        const Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            StatusBadge(label: 'Online', tone: Tone.success, icon: AppIcons.online),
            StatusBadge(label: 'Aguardando', tone: Tone.warning),
            StatusBadge(label: 'Bloqueado', tone: Tone.danger, icon: AppIcons.blocked),
            StatusBadge(label: 'Hora de dormir', tone: Tone.rest),
            StatusBadge(label: 'Sem limite', showIcon: false),
          ],
        ),
        const SectionGap(),
        AppSection(
          title: 'Tempo de hoje',
          actionLabel: 'Ajustar',
          onAction: () {},
          child: AppPanel(
            child: Column(
              children: <Widget>[
                TimeRing(
                  progress: 0.47,
                  semanticLabel: 'Restam 1 hora e 20 minutos de 2 horas e 30 minutos',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('1h 20min', style: context.textStyles.metricLarge),
                      Text('restam hoje', style: context.text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const MetricRow(
                  metrics: <MetricTile>[
                    MetricTile(value: '1h 10min', label: 'Usado'),
                    MetricTile(value: '2h 30min', label: 'Limite'),
                    MetricTile(value: '+15min', label: 'Extra', tone: Tone.info),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SectionGap(),
        AppSection(
          title: 'Mais usados hoje',
          child: AppListGroup(
            children: <Widget>[
              for (final (String name, String time, double f) in <(String, String, double)>[
                ('YouTube', '33min', 1),
                ('Brawl Stars', '25min', 0.76),
                ('WhatsApp', '20min', 0.6),
              ])
                AppListRow(
                  leading: InitialAvatar(name: name),
                  title: name,
                  titleStyle: context.text.bodyLarge,
                  trailing: Text(time, style: context.textStyles.metricSmall),
                  below: UsageBar(fraction: f),
                ),
            ],
          ),
        ),
        const SectionGap(),
        AppSection(
          title: 'Regras',
          child: AppListGroup(
            children: <Widget>[
              AppListRow(
                leading: const AppIconTile(icon: AppIcons.dailyLimit),
                title: 'Limite diário',
                subtitle: '2h 30min por dia',
                onTap: () {},
              ),
              AppListRow(
                leading: const AppIconTile(icon: AppIcons.bedtime, tone: Tone.rest),
                title: 'Hora de dormir',
                subtitle: 'Todos os dias, das 21:00 às 07:00',
                onTap: () {},
              ),
              AppListRow(
                leading: const AppIconTile(icon: AppIcons.apps),
                title: 'Aplicativos',
                subtitle: '1 bloqueado, 1 exceção',
                trailing: const StatusBadge(label: '1 novo', tone: Tone.warning),
                onTap: () {},
              ),
            ],
          ),
        ),
        const SectionGap(),
        const SyncStatusLine(
          state: SyncState.applied,
          detail: 'O aparelho confirmou a versão atual há 2 min.',
        ),
        const SizedBox(height: AppSpacing.md),
        const SyncStatusLine(
          state: SyncState.pending,
          detail: 'Salvo. O aparelho aplica assim que receber.',
        ),
        const SizedBox(height: AppSpacing.md),
        const SyncStatusLine(
          state: SyncState.offline,
          detail: 'As alterações serão enviadas quando ele voltar a ficar online.',
        ),
      ],
    );
  }
}

class _FeedbackPage extends StatelessWidget {
  const _FeedbackPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Retorno')),
      bottomNavigationBar: StickyActionBar(
        message: 'As mudanças são enviadas ao aparelho de João.',
        child: AppButton.primary(label: 'Salvar regras', onPressed: () {}),
      ),
      body: AppPageBody(
        children: <Widget>[
          AppBanner(
            tone: Tone.danger,
            title: 'Não foi possível sincronizar o novo limite',
            message: 'A configuração anterior continua ativa no aparelho.',
            actionLabel: 'Tentar de novo',
            onAction: () {},
          ),
          const SizedBox(height: AppSpacing.md),
          const AppBanner(
            tone: Tone.warning,
            title: 'Aparelho sem conexão',
            message: 'As alterações serão enviadas quando ele voltar a ficar online.',
          ),
          const SizedBox(height: AppSpacing.md),
          const AppBanner(tone: Tone.success, message: 'Regras aplicadas no aparelho de João.'),
          const SizedBox(height: AppSpacing.md),
          const AppBanner(
            tone: Tone.rest,
            title: 'Hora de dormir',
            message: 'O aparelho fica em pausa até as 07:00.',
          ),
          const SizedBox(height: AppSpacing.md),
          AppBanner(
            message: 'Os horários seguem o fuso do aparelho da criança.',
            actionLabel: 'Saiba mais',
            onAction: () {},
          ),
          const SectionGap(),
          const StepList(
            current: 1,
            steps: <String>[
              'Crie a conta e uma senha administrativa forte.',
              'Gere um código de vinculação e digite no aparelho da criança.',
              'Confirme o vínculo aqui e defina as regras.',
            ],
          ),
          const SectionGap(),
          AppPanel(
            child: EmptyState(
              compact: true,
              icon: AppIcons.devices,
              title: 'Nenhum aparelho vinculado',
              message: 'Vincule o celular da criança para definir limites e ver relatórios.',
              actionLabel: 'Vincular aparelho',
              onAction: () {},
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppPanel(
            child: ErrorState(
              compact: true,
              title: 'Não foi possível carregar os relatórios',
              message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
              icon: AppIcons.offline,
              onRetry: () {},
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const SkeletonListGroup(),
        ],
      ),
    );
  }
}

class _ChildPage extends StatelessWidget {
  const _ChildPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ChildPageBody(
          children: <Widget>[
            Text('Olá, João!', style: context.text.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusBadge(label: 'Controle parental ativo', tone: Tone.info),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPanel(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: <Widget>[
                  TimeRing(
                    progress: 0.47,
                    size: 220,
                    strokeWidth: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('1:20', style: context.textStyles.metricHero),
                        Text('para usar hoje', style: context.text.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Você usou 1h 10min de 2h 30min.',
                    style: context.text.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: 'Pedir mais tempo',
              icon: AppIcons.extraTime,
              onPressed: () {},
              expand: true,
            ),
            const SizedBox(height: AppSpacing.xl),
            const ChildHeader(
              icon: AppIcons.bedtime,
              tone: Tone.rest,
              title: 'Hora de descansar',
              message: 'O celular volta às 07:00. Ligações de emergência continuam liberadas.',
            ),
            const SizedBox(height: AppSpacing.lg),
            const BulletLine(text: 'Tempo por dia: 2h 30min.', icon: AppIcons.dailyLimit),
            const BulletLine(
              text: 'Hora de dormir: das 21:00 às 07:00.',
              icon: AppIcons.bedtime,
              tone: Tone.rest,
            ),
            const BulletLine(
              text: 'WhatsApp e Escola Digital sempre liberados.',
              icon: AppIcons.allowed,
              tone: Tone.success,
            ),
          ],
        ),
      ),
    );
  }
}
