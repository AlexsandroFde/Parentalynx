import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/route_paths.dart';
import '../../../../../shared/design_system/design_system.dart';
import '../../../../child_device/domain/entities/child_device.dart';

/// Protecao do aparelho em duas linhas: o nivel garantido pelo modo de instalacao e o
/// funcionamento das permissoes. Os detalhes (o que cada nivel garante, como resolver cada
/// permissao, codigo offline, dados e desvincular) ficam no detalhe do aparelho.
class DashboardProtectionSection extends StatelessWidget {
  const DashboardProtectionSection({required this.device, super.key});

  final ChildDevice device;

  @override
  Widget build(BuildContext context) {
    final DeviceManagementMode mode = device.managementMode;
    final DeviceSnapshot? snapshot = device.snapshot;
    final int problems = snapshot == null
        ? 0
        : snapshot.issues.length + (snapshot.enforcementActive ? 0 : 1);
    void openDevice() => context.push(GuardianPaths.device(device.id));
    return AppSection(
      title: 'Proteção',
      child: AppListGroup(
        footer: 'Código de acesso offline, dados e desvincular ficam nos detalhes do aparelho.',
        children: <Widget>[
          AppListRow(
            leading: AppIconTile(
              icon: mode.isSystemEnforced ? AppIcons.protectionGood : AppIcons.protection,
              tone: mode.isSystemEnforced ? Tone.success : Tone.neutral,
            ),
            title: 'Nível de proteção',
            subtitle: mode.label,
            below: mode.isSystemEnforced
                ? const StatusBadge(
                    label: 'Garantido pelo sistema',
                    tone: Tone.success,
                    icon: AppIcons.verifiedUser,
                  )
                : const StatusBadge(label: 'Não garantido'),
            showChevron: true,
            onTap: openDevice,
          ),
          AppListRow(
            leading: AppIconTile(
              icon: AppIcons.admin,
              tone: snapshot == null
                  ? Tone.neutral
                  : problems == 0
                  ? Tone.success
                  : Tone.warning,
            ),
            title: 'Permissões e funcionamento',
            subtitle: snapshot == null
                ? 'O aparelho ainda não informou.'
                : problems == 0
                ? 'Tudo funcionando no aparelho.'
                : problems == 1
                ? '1 problema para resolver.'
                : '$problems problemas para resolver.',
            showChevron: true,
            onTap: openDevice,
          ),
        ],
      ),
    );
  }
}
