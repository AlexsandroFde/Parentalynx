import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/alert_type.dart';
import '../../domain/entities/notification_preferences.dart';
import '../bloc/notification_permission/notification_permission_bloc.dart';
import '../bloc/notification_prefs/notification_prefs_bloc.dart';
import '../texts/notification_texts.dart';
import '../widgets/alert_icon.dart';
import '../widgets/notification_permission_prompt.dart';

/// Preferencias de notificacao: um interruptor por tipo de alerta, agrupados por assunto e
/// com a consequencia de desligar explicada abaixo de cada grupo.
///
/// Desligar um tipo nao apaga os alertas: eles continuam na central, so deixam de notificar.
/// A mudanca aparece na hora e e desfeita se o servidor recusar; enquanto grava, a linha diz
/// "Salvando". Espera um [NotificationPrefsBloc] acima na arvore.
class NotificationPrefsPage extends StatelessWidget {
  const NotificationPrefsPage({super.key});

  void _onSaved(
    BuildContext context,
    NotificationPrefsState previous,
    NotificationPrefsState state,
  ) {
    if (state.action case ActionFailed(:final failure)) {
      // Diz qual escolha nao foi salva e que a anterior continua valendo (heuristica 9).
      final Set<AlertType> finished = previous.saving.difference(state.saving);
      final String which = finished.length == 1 ? '"${finished.first.label}"' : 'a escolha';
      showAppSnackBar(
        context,
        'Não foi possível salvar $which. A preferência anterior continua valendo. '
        '${failure.message}',
        tone: Tone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool notificationsOff = context.select<NotificationPermissionBloc, bool>(
      (NotificationPermissionBloc bloc) => bloc.state.isDenied,
    );
    NotificationPrefsState last = context.read<NotificationPrefsBloc>().state;
    return BlocConsumer<NotificationPrefsBloc, NotificationPrefsState>(
      listenWhen: (NotificationPrefsState previous, NotificationPrefsState current) {
        last = previous;
        return previous.action != current.action;
      },
      listener: (BuildContext context, NotificationPrefsState state) {
        _onSaved(context, last, state);
      },
      builder: (BuildContext context, NotificationPrefsState state) {
        final NotificationPreferences? preferences = state.preferences;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Preferências de notificação'),
            actions: const <Widget>[
              HelpButton(title: 'Como funcionam os alertas', topics: alertsHelpTopics),
              SizedBox(width: AppSpacing.xs),
            ],
          ),
          body: AppPageBody(
            children: <Widget>[
              const AppPageHeader(
                title: 'Quais avisos tocam no celular',
                subtitle:
                    'Valem para todos os aparelhos da conta. Um aviso desligado continua na '
                    'central de alertas, só não gera notificação.',
              ),
              if (notificationsOff) ...<Widget>[
                AppBanner(
                  tone: Tone.warning,
                  icon: AppIcons.notificationOff,
                  title: 'Notificações desativadas no sistema',
                  message:
                      'As escolhas abaixo ficam salvas, mas só tocam no celular depois que você '
                      'permitir as notificações do ParentaLynx.',
                  actionLabel: 'Ativar notificações',
                  onAction: () => requestNotificationsWithExplanation(context),
                ),
                const SectionGap(),
              ],
              StateSwitcher(
                child: preferences == null
                    ? const KeyedSubtree(
                        key: ValueKey<String>('carregando'),
                        child: SkeletonListGroup(rows: 5),
                      )
                    : KeyedSubtree(
                        key: const ValueKey<String>('preferencias'),
                        child: _PreferenceGroups(preferences: preferences, saving: state.saving),
                      ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(AppIcons.clock, size: AppSizes.iconSm, color: context.colors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(alertDeliveryNote, style: context.text.bodySmall)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreferenceGroups extends StatelessWidget {
  const _PreferenceGroups({required this.preferences, required this.saving});

  final NotificationPreferences preferences;
  final Set<AlertType> saving;

  @override
  Widget build(BuildContext context) {
    final NotificationPrefsBloc bloc = context.read<NotificationPrefsBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < alertPreferenceGroups.length; i++) ...<Widget>[
          if (i > 0) const SectionGap(),
          AppSection(
            title: alertPreferenceGroups[i].title,
            child: AppListGroup(
              footer: alertPreferenceGroups[i].footer,
              children: <Widget>[
                for (final AlertType type in alertPreferenceGroups[i].types)
                  AppSwitchRow(
                    title: type.label,
                    subtitle: saving.contains(type) ? 'Salvando…' : type.description,
                    icon: AlertVisual.forType(type.code).icon,
                    tone: AlertVisual.forType(type.code).tone,
                    value: preferences.notifies(type),
                    onChanged: saving.contains(type)
                        ? null
                        : (bool value) {
                            bloc.add(NotificationPreferenceToggled(type, enabled: value));
                          },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
