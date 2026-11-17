import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/domain/policy.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../devices/domain/device.dart';
import 'widgets/rule_scaffold.dart';

/// Protecao contra adulteracao e travas do modo dispositivo gerenciado (Device Owner).
class ProtectionPage extends StatelessWidget {
  const ProtectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RuleEditorScaffold(
      title: 'Proteção',
      children: (BuildContext context, RuleEditing editing) {
        final ProtectionPolicy protection = editing.draft.protection;
        final DeviceManagementMode mode = editing.device.managementMode;
        final bool owner = mode == DeviceManagementMode.deviceOwner;

        void change(ProtectionPolicy Function(ProtectionPolicy current) update) {
          editing.update((Policy p) => p.copyWith(protection: update(p.protection)));
        }

        ValueChanged<bool>? ownerOnly(ProtectionPolicy Function(ProtectionPolicy, bool) update) {
          return owner ? (bool v) => change((ProtectionPolicy p) => update(p, v)) : null;
        }

        return <Widget>[
          SectionCard(
            title: 'Modo deste aparelho: ${mode.label}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final String item in guaranteesOf(mode).guaranteed)
                  _Bullet(icon: Icons.check_circle_outline, tone: Tone.success, text: item),
                for (final String item in guaranteesOf(mode).notGuaranteed)
                  _Bullet(icon: Icons.report_gmailerrorred, tone: Tone.warning, text: item),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchCard(
            icon: Icons.gpp_maybe_outlined,
            title: 'Bloquear se a proteção for desativada',
            subtitle:
                'Se uma permissão essencial for revogada no aparelho e ainda houver como '
                'bloquear, tudo que não for exceção fica bloqueado. Desligado, você só recebe '
                'o alerta.',
            value: protection.lockOnTamper,
            onChanged: (bool v) => change((ProtectionPolicy p) => p.copyWith(lockOnTamper: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Travas do sistema',
            subtitle: owner
                ? 'Aplicadas pelo próprio Android neste aparelho.'
                : 'Disponíveis só no modo dispositivo gerenciado.',
            child: Column(
              children: <Widget>[
                if (!owner)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: NoticeBanner(
                      icon: Icons.info_outline,
                      message:
                          'Em uma instalação comum o Android não permite que um aplicativo '
                          'impeça a própria desinstalação nem trave as configurações. Para '
                          'usar estas travas, o aparelho precisa ser provisionado como '
                          'dispositivo gerenciado (veja a documentação de instalação).',
                    ),
                  ),
                SwitchRow(
                  title: 'Impedir a desinstalação do ParentaLynx',
                  value: protection.blockUninstall,
                  onChanged: ownerOnly(
                    (ProtectionPolicy p, bool v) => p.copyWith(blockUninstall: v),
                  ),
                ),
                SwitchRow(
                  title: 'Impedir o modo de segurança',
                  value: protection.blockSafeBoot,
                  onChanged: ownerOnly(
                    (ProtectionPolicy p, bool v) => p.copyWith(blockSafeBoot: v),
                  ),
                ),
                SwitchRow(
                  title: 'Impedir a restauração de fábrica pelas Configurações',
                  value: protection.blockFactoryReset,
                  onChanged: ownerOnly(
                    (ProtectionPolicy p, bool v) => p.copyWith(blockFactoryReset: v),
                  ),
                ),
                SwitchRow(
                  title: 'Impedir a alteração de data e hora',
                  value: protection.blockDateTimeChange,
                  onChanged: ownerOnly(
                    (ProtectionPolicy p, bool v) => p.copyWith(blockDateTimeChange: v),
                  ),
                ),
                SwitchRow(
                  title: 'Impedir a criação de outros usuários',
                  value: protection.blockAddUser,
                  onChanged: ownerOnly((ProtectionPolicy p, bool v) => p.copyWith(blockAddUser: v)),
                ),
                SwitchRow(
                  title: 'Impedir a instalação de fontes desconhecidas',
                  value: protection.blockUnknownSources,
                  onChanged: ownerOnly(
                    (ProtectionPolicy p, bool v) => p.copyWith(blockUnknownSources: v),
                  ),
                ),
                SwitchRow(
                  title: 'Impedir a depuração USB',
                  value: protection.blockUsbDebugging,
                  onChanged: ownerOnly(
                    (ProtectionPolicy p, bool v) => p.copyWith(blockUsbDebugging: v),
                  ),
                ),
              ],
            ),
          ),
        ];
      },
    );
  }
}

/// O que cada modo de gerenciamento garante e o que nao garante (resumo de
/// `docs/01-capacidades-android.md`).
({List<String> guaranteed, List<String> notGuaranteed}) guaranteesOf(DeviceManagementMode mode) {
  switch (mode) {
    case DeviceManagementMode.deviceOwner:
      return (
        guaranteed: const <String>[
          'Apps bloqueados são suspensos pelo sistema e não chegam a abrir.',
          'O bloqueio continua valendo depois de reiniciar e se o app for encerrado.',
          'A desinstalação e o modo de segurança podem ser impedidos.',
        ],
        notGuaranteed: const <String>[
          'A restauração pelo modo de recuperação do aparelho não pode ser impedida.',
        ],
      );
    case DeviceManagementMode.deviceAdmin:
      return (
        guaranteed: const <String>[
          'Contagem de tempo e bloqueio de apps funcionam enquanto as permissões estiverem '
              'ativas.',
          'Desinstalar exige desativar o administrador antes, e isso gera um alerta.',
        ],
        notGuaranteed: const <String>[
          'A criança consegue desativar as permissões. Você é avisado quando isso acontece.',
          'Modo de segurança e restauração de fábrica não podem ser impedidos.',
        ],
      );
    case DeviceManagementMode.standard:
      return (
        guaranteed: const <String>[
          'Contagem de tempo e bloqueio de apps funcionam enquanto as permissões estiverem '
              'ativas.',
          'Toda adulteração que o app consegue detectar gera um alerta.',
        ],
        notGuaranteed: const <String>[
          'A criança consegue desativar as permissões ou desinstalar o app.',
          'Um app bloqueado pode aparecer por uma fração de segundo antes do bloqueio.',
          'Modo de segurança e restauração de fábrica não podem ser impedidos.',
        ],
      );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.tone, required this.text});

  final IconData icon;
  final Tone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: tone.foreground(context)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
