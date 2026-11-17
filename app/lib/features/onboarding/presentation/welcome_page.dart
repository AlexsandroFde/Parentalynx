import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/platform/native_providers.dart';
import '../../../shared/widgets/feedback_views.dart';
import 'server_sheet.dart';

/// Primeira tela: explica o que o app faz e deixa escolher o modo deste aparelho.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  AppMode? _choosing;

  Future<void> _choose(AppMode mode) async {
    if (_choosing != null) {
      return;
    }
    if (!AppConfig.isAcceptableServerUrl(ref.read(serverUrlProvider))) {
      final bool configured = await showServerSheet(context);
      if (!configured || !mounted) {
        return;
      }
    }
    setState(() => _choosing = mode);
    try {
      await ref.read(appModeProvider.notifier).setMode(mode);
    } on Object catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _choosing = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            // Pagina curta e estatica: coluna rolavel, sem construcao sob demanda.
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _Brand(),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Como este aparelho será usado?', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'O mesmo aplicativo é instalado no aparelho do responsável e no aparelho da '
                    'criança. Escolha o papel deste aparelho.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _ModeCard(
                    icon: Icons.shield_outlined,
                    title: 'Sou o responsável',
                    description:
                        'Defina limites de tempo, escolha os aplicativos permitidos e acompanhe '
                        'os relatórios de uso.',
                    busy: _choosing == AppMode.guardian,
                    enabled: _choosing == null,
                    onTap: () => _choose(AppMode.guardian),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ModeCard(
                    icon: Icons.child_care_outlined,
                    title: 'Este é o aparelho da criança',
                    description:
                        'Vincule este aparelho ao responsável com um código. As regras passam a '
                        'valer aqui.',
                    busy: _choosing == AppMode.child,
                    enabled: _choosing == null,
                    onTap: () => _choose(AppMode.child),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const NoticeBanner(
                    icon: Icons.visibility_outlined,
                    title: 'Controle transparente',
                    message:
                        'O ParentaLynx nunca fica escondido. A criança vê que o controle está '
                        'ativo, quais regras valem e quem é o responsável. O app não lê '
                        'mensagens, não registra o que é digitado e não captura a tela.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: TextButton.icon(
                      onPressed: _choosing == null ? () => showServerSheet(context) : null,
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: const Text('Configurar servidor'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(Icons.family_restroom, color: theme.colorScheme.onPrimary, size: 30),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(AppConfig.appName, style: theme.textTheme.headlineMedium),
              Text(
                'Controle parental claro e respeitoso',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: theme.colorScheme.onPrimaryContainer, size: 28),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (busy)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
