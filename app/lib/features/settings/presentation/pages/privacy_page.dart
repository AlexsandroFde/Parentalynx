import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../authentication/domain/entities/guardian_account.dart';
import '../bloc/account_settings/account_settings_bloc.dart';
import '../texts/settings_texts.dart';

/// Dados e privacidade: o que e coletado, o que nao e, por quanto tempo fica guardado e os
/// limiares dos alertas. Segue `docs/01-capacidades-android.md`, secao 7.
///
/// Espera um [AccountSettingsBloc] acima na arvore.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

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

  void _onAction(BuildContext context, AccountSettingsState state) {
    switch (state.action) {
      case ActionSucceeded(:final String? message):
        if (message != null) {
          showAppSnackBar(context, message, tone: Tone.success);
        }
      case ActionFailed(:final failure):
        showFailure(context, failure);
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
      buildWhen: (AccountSettingsState previous, AccountSettingsState current) {
        return previous.settings != current.settings;
      },
      builder: (BuildContext context, AccountSettingsState state) {
        final GuardianSettings? settings = state.settings;
        if (settings == null) {
          return const Scaffold(body: LoadingView());
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Dados e privacidade')),
          body: PageBody(
            children: <Widget>[
              const SectionCard(
                title: 'O que o ParentaLynx coleta',
                subtitle: 'No aparelho monitorado, e só o que está nesta lista.',
                child: _BulletList(items: _collected, icon: Icons.check, tone: Tone.info),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionCard(
                title: 'O que não é coletado',
                subtitle: 'O aplicativo não tem como acessar estes dados.',
                child: _BulletList(items: _notCollected, icon: Icons.block, tone: Tone.success),
              ),
              const SizedBox(height: AppSpacing.lg),
              const NoticeBanner(
                icon: Icons.visibility_outlined,
                message:
                    'A criança vê no aparelho dela que o controle está ativo, quais regras valem '
                    'e quem é o responsável. O aplicativo nunca se esconde.',
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                title: 'Retenção',
                subtitle:
                    'Sessões, eventos, navegação e alertas mais antigos que o prazo são apagados '
                    'do servidor todos os dias. Os totais diários ficam por 400 dias.',
                padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
                child: _ChoiceTile<int>(
                  icon: Icons.auto_delete_outlined,
                  title: 'Guardar o histórico por',
                  value: settings.retentionDays,
                  options: const <int>[30, 60, 90, 180, 365],
                  labelOf: retentionDaysLabel,
                  onChanged: (int days) => _save(context, settings.copyWith(retentionDays: days)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                title: 'Limiares dos alertas',
                padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
                child: Column(
                  children: <Widget>[
                    _ChoiceTile<int>(
                      icon: Icons.timelapse,
                      title: 'Avisar "pouco tempo" quando faltar',
                      value: settings.lowTimeMinutes,
                      options: const <int>[5, 10, 15, 30],
                      labelOf: formatMinutes,
                      onChanged: (int minutes) =>
                          _save(context, settings.copyWith(lowTimeMinutes: minutes)),
                    ),
                    const Divider(height: 1, indent: 56),
                    _ChoiceTile<int>(
                      icon: Icons.sync_problem,
                      title: 'Avisar "sem sincronizar" após',
                      value: settings.syncStaleMinutes,
                      options: const <int>[30, 60, 180, 360, 720, 1440],
                      labelOf: formatMinutes,
                      onChanged: (int minutes) =>
                          _save(context, settings.copyWith(syncStaleMinutes: minutes)),
                    ),
                    const Divider(height: 1, indent: 56),
                    _ChoiceTile<int>(
                      icon: Icons.cloud_off_outlined,
                      title: 'Avisar "aparelho offline" após',
                      value: settings.offlineHours,
                      options: const <int>[6, 12, 24, 48, 72, 168],
                      labelOf: offlineHoursLabel,
                      onChanged: (int hours) =>
                          _save(context, settings.copyWith(offlineHours: hours)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const NoticeBanner(
                tone: Tone.neutral,
                icon: Icons.delete_outline,
                title: 'Apagar dados',
                message:
                    'O histórico de cada aparelho pode ser exportado ou apagado em Mais, '
                    'Aparelhos vinculados. A conta inteira pode ser excluída em Conta e senha.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items, required this.icon, required this.tone});

  final List<String> items;
  final IconData icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final String item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 16, color: tone.foreground(context)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Linha de ajuste com o valor atual. Ao tocar, abre a lista de opcoes.
class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final List<T> options;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  Future<void> _choose(BuildContext context) async {
    final T? chosen = await showDialog<T>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(title),
          children: <Widget>[
            for (final T option in <T>{...options, value})
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(option),
                child: Row(
                  children: <Widget>[
                    Icon(
                      option == value ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 20,
                      color: option == value ? Theme.of(context).colorScheme.primary : null,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(labelOf(option)),
                  ],
                ),
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
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(labelOf(value)),
      trailing: const Icon(Icons.expand_more),
      onTap: () => _choose(context),
    );
  }
}
