import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../data/api_account_repository.dart';
import '../domain/account_repository.dart';

/// Registro de alteracoes administrativas da conta, do mais novo para o mais antigo.
class AuditLogPage extends ConsumerStatefulWidget {
  const AuditLogPage({super.key});

  @override
  ConsumerState<AuditLogPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditLogPage> {
  final List<AuditEntry> _entries = <AuditEntry>[];
  int? _nextBefore;
  bool _loading = true;
  bool _hasMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final AuditPage page = await ref
          .read(accountRepositoryProvider)
          .audit(before: reset ? null : _nextBefore);
      if (!mounted) {
        return;
      }
      setState(() {
        if (reset) {
          _entries.clear();
        }
        _entries.addAll(page.entries);
        _nextBefore = page.nextBefore;
        _hasMore = page.nextBefore != null && page.entries.isNotEmpty;
        _loading = false;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  static IconData _iconFor(String action) {
    if (action.startsWith('auth') || action.startsWith('session')) {
      return Icons.login;
    }
    if (action.startsWith('policy')) {
      return Icons.tune;
    }
    if (action.startsWith('pairing') || action.startsWith('device')) {
      return Icons.smartphone_outlined;
    }
    if (action.startsWith('guardian') || action.startsWith('account')) {
      return Icons.person_outline;
    }
    return Icons.history;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Object? error = _error;
    final Widget body;
    if (_entries.isEmpty && _loading) {
      body = const LoadingView();
    } else if (_entries.isEmpty && error != null) {
      body = FailureView(error: error, onRetry: () => _load(reset: true));
    } else if (_entries.isEmpty) {
      body = const EmptyState(
        icon: Icons.history,
        title: 'Nenhuma alteração registrada',
        message: 'Mudanças de regras, vínculos e acessos à conta aparecem aqui.',
      );
    } else {
      body = PageBody(
        children: <Widget>[
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (int index = 0; index < _entries.length; index++) ...<Widget>[
                  if (index > 0) const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Icon(_iconFor(_entries[index].action)),
                    title: Text(
                      _entries[index].summary.isEmpty
                          ? _entries[index].action
                          : _entries[index].summary,
                    ),
                    subtitle: Text(
                      <String>[
                        formatRelativeMs(_entries[index].at),
                        ?_entries[index].deviceName,
                        ?_entries[index].ip,
                      ].join(' · '),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            NoticeBanner(
              tone: Tone.danger,
              message: 'Não foi possível carregar mais registros.',
              actionLabel: 'Tentar de novo',
              onAction: _load,
            ),
          ],
          if (_hasMore && error == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Center(
                child: _loading
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : TextButton(onPressed: _load, child: const Text('Carregar mais antigos')),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'O registro guarda as alterações dos últimos 365 dias.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de alterações')),
      body: body,
    );
  }
}
