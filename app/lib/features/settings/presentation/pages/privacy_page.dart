import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../authentication/domain/entities/guardian_account.dart';
import '../../../authentication/presentation/widgets/auth_widgets.dart';
import '../bloc/account_settings/account_settings_bloc.dart';
import '../texts/settings_texts.dart';

/// Dados e privacidade: por quanto tempo o historico fica guardado, os avisos automaticos, o
/// que e coletado e o que nunca e. Segue `docs/01-capacidades-android.md`, secao 7.
///
/// Espera um [AccountSettingsBloc] acima na arvore.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  static const List<int> _retentionOptions = <int>[30, 60, 90, 180, 365];

  static const List<String> _collected = <String>[
    'Lista de aplicativos instalados (nome, pacote, ícone e categoria).',
    'Sessões de uso por aplicativo (início, fim e duração).',
    'Tentativas de abrir aplicativos bloqueados e eventos de bloqueio e liberação.',
    'Estado das permissões e eventos de segurança (relógio alterado, reinicialização, '
        'proteção desativada).',
    'Nível de bateria e estado de conexão.',
    'Endereços e títulos das páginas abertas no navegador gerenciado, e só nele.',
  ];

  static const List<String> _notCollected = <String>[
    'Teclas digitadas e senhas.',
    'Conteúdo de mensagens e de telas.',
    'Capturas ou gravação de tela, áudio e câmera.',
    'Fotos, arquivos, contatos e registro de chamadas.',
    'Localização.',
    'Navegação feita em outros aplicativos ou navegadores.',
  ];

  void _save(BuildContext context, GuardianSettings settings) {
    context.read<AccountSettingsBloc>().add(AccountSettingsChanged(settings));
  }

  /// Encurtar o prazo apaga o historico mais antigo na limpeza diaria: pede confirmacao.
  /// Aumentar nao apaga nada e vale na hora.
  Future<void> _changeRetention(BuildContext context, GuardianSettings settings, int days) async {
    if (days == settings.retentionDays) {
      return;
    }
    if (days < settings.retentionDays) {
      final bool confirmed = await showConfirmDialog(
        context,
        title: 'Guardar o histórico por $days dias?',
        message:
            'Sessões de uso, eventos, navegação e alertas com mais de $days dias são apagados '
            'do servidor na próxima limpeza diária.',
        consequence: 'O que for apagado não pode ser recuperado.',
        confirmLabel: 'Reduzir para $days dias',
        destructive: true,
        icon: AppIcons.autoDelete,
      );
      if (!confirmed || !context.mounted) {
        return;
      }
    }
    _save(context, settings.copyWith(retentionDays: days));
  }

  void _onAction(BuildContext context, AccountSettingsState state) {
    switch (state.action) {
      case ActionSucceeded(:final String? message):
        if (message != null) {
          showAppSnackBar(context, message, tone: Tone.success);
        }
      case ActionFailed(:final failure):
        showAppSnackBar(
          context,
          'Não foi possível salvar o ajuste. O valor anterior continua valendo. '
          '${failure.message}',
          tone: Tone.danger,
        );
      case ActionIdle() || ActionRunning():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountSettingsBloc, AccountSettingsState>(
      listenWhen: (AccountSettingsState previous, AccountSettingsState current) {
        return previous.action != current.action;
      },
      listener: _onAction,
      builder: (BuildContext context, AccountSettingsState state) {
        final GuardianSettings? settings = state.settings;
        final bool saving = state.action.isRunning;
        return Scaffold(
          appBar: AppBar(title: const Text('Dados e privacidade')),
          body: StateSwitcher(
            child: settings == null
                ? const KeyedSubtree(key: ValueKey<String>('carregando'), child: LoadingState())
                : KeyedSubtree(
                    key: const ValueKey<String>('ajustes'),
                    child: AppPageBody(
                      children: <Widget>[
                        AppSection(
                          title: 'Guardar o histórico por',
                          subtitle:
                              'Sessões, eventos, navegação e alertas mais antigos que o prazo '
                              'são apagados do servidor todos os dias.',
                          trailing: saving ? const InlineProgress(label: 'Salvando') : null,
                          child: AppPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                AppChoiceChips<int>(
                                  choices: <AppChoice<int>>[
                                    for (final int days in <int>{
                                      ..._retentionOptions,
                                      settings.retentionDays,
                                    }.toList()..sort())
                                      AppChoice<int>(value: days, label: retentionDaysLabel(days)),
                                  ],
                                  selected: settings.retentionDays,
                                  onSelected: saving
                                      ? null
                                      : (int days) => _changeRetention(context, settings, days),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'Os totais diários de uso ficam por 400 dias, para os '
                                  'relatórios do ano.',
                                  style: context.text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SectionGap(),
                        AppSection(
                          title: 'Avisos automáticos',
                          subtitle: 'Quando o painel avisa sobre tempo e conexão dos aparelhos.',
                          child: AppListGroup(
                            children: <Widget>[
                              _ThresholdRow(
                                icon: AppIcons.timeRunningOut,
                                title: 'Pouco tempo restante',
                                prefix: 'Quando faltar',
                                value: settings.lowTimeMinutes,
                                options: const <int>[5, 10, 15, 30],
                                labelOf: formatMinutes,
                                enabled: !saving,
                                onChanged: (int minutes) =>
                                    _save(context, settings.copyWith(lowTimeMinutes: minutes)),
                              ),
                              _ThresholdRow(
                                icon: AppIcons.syncProblem,
                                title: 'Sem sincronizar',
                                prefix: 'Depois de',
                                value: settings.syncStaleMinutes,
                                options: const <int>[30, 60, 180, 360, 720, 1440],
                                labelOf: formatMinutes,
                                enabled: !saving,
                                onChanged: (int minutes) =>
                                    _save(context, settings.copyWith(syncStaleMinutes: minutes)),
                              ),
                              _ThresholdRow(
                                icon: AppIcons.offline,
                                title: 'Aparelho offline',
                                prefix: 'Depois de',
                                value: settings.offlineHours,
                                options: const <int>[6, 12, 24, 48, 72, 168],
                                labelOf: offlineHoursLabel,
                                enabled: !saving,
                                onChanged: (int hours) =>
                                    _save(context, settings.copyWith(offlineHours: hours)),
                              ),
                            ],
                          ),
                        ),
                        const SectionGap(),
                        const AppSection(
                          title: 'O que o ParentaLynx coleta',
                          subtitle: 'No aparelho da criança, e só o que está nesta lista.',
                          child: _Bullets(items: _collected, icon: AppIcons.check),
                        ),
                        const SectionGap(),
                        const AppSection(
                          title: 'O que nunca é coletado',
                          subtitle: 'O aplicativo não tem como acessar estes dados.',
                          child: _Bullets(
                            items: _notCollected,
                            icon: AppIcons.hide,
                            tone: Tone.success,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const AppBanner(
                          icon: AppIcons.show,
                          title: 'Controle transparente',
                          message:
                              'A criança vê no aparelho dela que o controle está ativo, quais '
                              'regras valem e quem é o responsável. O aplicativo nunca se '
                              'esconde.',
                        ),
                        const SectionGap(),
                        AppSection(
                          title: 'Apagar dados',
                          child: AppListGroup(
                            children: <Widget>[
                              AppListRow(
                                leading: const AppIconTile(icon: AppIcons.devices),
                                title: 'Histórico de um aparelho',
                                subtitle: 'Exporte ou apague no detalhe de cada aparelho.',
                                onTap: () => context.push(GuardianPaths.devices),
                              ),
                              AppListRow(
                                leading: const AppIconTile(
                                  icon: AppIcons.deleteForever,
                                  tone: Tone.danger,
                                ),
                                title: 'A conta inteira',
                                subtitle: 'Exclua a conta e todos os dados em Conta e senha.',
                                onTap: () => context.go(GuardianPaths.account),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// Lista explicativa com marcadores, em um painel.
class _Bullets extends StatelessWidget {
  const _Bullets({required this.items, required this.icon, this.tone = Tone.info});

  final List<String> items;
  final IconData icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final String item in items) BulletLine(text: item, icon: icon, tone: tone),
        ],
      ),
    );
  }
}

/// Ajuste de um aviso automatico: mostra o valor atual e, ao tocar, as opcoes em uma folha.
class _ThresholdRow extends StatelessWidget {
  const _ThresholdRow({
    required this.icon,
    required this.title,
    required this.prefix,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;

  /// Comeco da frase do valor ("Quando faltar", "Depois de").
  final String prefix;
  final int value;
  final List<int> options;
  final String Function(int value) labelOf;
  final bool enabled;
  final ValueChanged<int> onChanged;

  Future<void> _choose(BuildContext context) async {
    final int? chosen = await showAppSheet<int>(
      context,
      title: title,
      subtitle: '$prefix:',
      builder: (BuildContext context) {
        return AppListGroup(
          dividerIndent: AppSpacing.lg + AppSizes.iconLg + AppSpacing.md,
          children: <Widget>[
            for (final int option in <int>{...options, value}.toList()..sort())
              AppRadioRow<int>(
                title: labelOf(option),
                value: option,
                groupValue: value,
                onChanged: (int picked) => Navigator.of(context).pop(picked),
              ),
          ],
        );
      },
    );
    if (chosen != null && chosen != value) {
      onChanged(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      leading: AppIconTile(icon: icon),
      title: title,
      subtitle: '$prefix ${labelOf(value)}',
      enabled: enabled,
      onTap: enabled ? () => _choose(context) : null,
    );
  }
}
