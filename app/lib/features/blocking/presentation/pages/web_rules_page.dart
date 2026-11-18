import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/widgets/rule_editor_scaffold.dart';
import '../../domain/services/web_policy_editing.dart';
import '../bloc/web_filter/web_filter_bloc.dart';

/// Regras de navegacao na internet: navegador gerenciado, filtros e listas de sites.
///
/// Espera um [WebFilterBloc] acima na arvore, ja iniciado para [device].
class WebRulesPage extends StatelessWidget {
  const WebRulesPage({required this.device, super.key});

  final ChildDevice device;

  @override
  Widget build(BuildContext context) {
    final WebFilterBloc bloc = context.read<WebFilterBloc>();
    final bool managed = device.managementMode == DeviceManagementMode.deviceOwner;
    return RuleEditorScaffold<WebFilterBloc, WebPolicy>(
      title: 'Navegação na internet',
      device: device,
      onSave: () => bloc.add(const WebFilterSaveRequested()),
      onDiscard: () => bloc.add(const WebFilterDiscardRequested()),
      onRetry: () => bloc.add(WebFilterStarted(device.id)),
      children: (BuildContext context, WebPolicy web) {
        void addDomain(WebDomainList list, String domain) {
          bloc.add(WebDomainAdded(list: list, domain: domain));
        }

        void removeDomain(WebDomainList list, String domain) {
          bloc.add(WebDomainRemoved(list: list, domain: domain));
        }

        return <Widget>[
          NoticeBanner(
            icon: Icons.travel_explore,
            title: 'O que é registrado e filtrado',
            message:
                'Só a navegação feita no navegador ParentaLynx é registrada e filtrada. O app '
                'não enxerga páginas abertas em outros navegadores ou aplicativos. Para que a '
                'criança use só o navegador gerenciado, bloqueie os outros navegadores.',
            actionLabel: 'Ver navegadores instalados',
            onAction: () => context.push(RulesPaths.appsInCategory('browser')),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Navegador gerenciado',
            child: Column(
              children: <Widget>[
                SwitchRow(
                  title: 'Disponibilizar o navegador ParentaLynx',
                  subtitle: 'Aparece no aparelho da criança como um app separado.',
                  value: web.managedBrowser,
                  onChanged: (bool value) => bloc.add(WebManagedBrowserChanged(value)),
                ),
                SwitchRow(
                  title: 'Registrar o histórico',
                  subtitle: 'Endereço, título e horário das páginas. A criança é avisada.',
                  value: web.logHistory,
                  onChanged: web.managedBrowser
                      ? (bool value) => bloc.add(WebHistoryLoggingChanged(value))
                      : null,
                ),
                SwitchRow(
                  title: 'Busca segura',
                  subtitle: 'Força o modo seguro nos buscadores conhecidos.',
                  value: web.safeSearch,
                  onChanged: web.managedBrowser
                      ? (bool value) => bloc.add(WebSafeSearchChanged(value))
                      : null,
                ),
                SwitchRow(
                  title: 'Filtro DNS familiar',
                  subtitle: managed
                      ? 'Bloqueia conteúdo adulto e sites maliciosos no aparelho inteiro.'
                      : 'Bloqueia conteúdo adulto e sites maliciosos no navegador gerenciado. '
                            'No aparelho inteiro só é garantido no modo dispositivo gerenciado.',
                  value: web.safeDns,
                  onChanged: (bool value) => bloc.add(WebSafeDnsChanged(value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Modo de filtragem',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SegmentedButton<WebMode>(
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<WebMode>>[
                    ButtonSegment<WebMode>(
                      value: WebMode.blocklist,
                      label: Text('Lista de bloqueio'),
                    ),
                    ButtonSegment<WebMode>(value: WebMode.allowlist, label: Text('Só autorizados')),
                  ],
                  selected: <WebMode>{web.mode},
                  onSelectionChanged: (Set<WebMode> value) {
                    bloc.add(WebModeChanged(value.first));
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  web.mode == WebMode.blocklist
                      ? 'Tudo é permitido, menos os sites e as categorias bloqueadas.'
                      : 'Só os sites da lista de autorizados podem ser abertos.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (web.mode == WebMode.allowlist)
            _DomainListCard(
              title: 'Sites autorizados',
              emptyText: 'Nenhum site autorizado. Nesse modo, nada poderá ser aberto.',
              emptyTone: Tone.warning,
              domains: web.allowedDomains,
              onAdd: (String domain) => addDomain(WebDomainList.allowed, domain),
              onRemove: (String domain) => removeDomain(WebDomainList.allowed, domain),
            )
          else ...<Widget>[
            SectionCard(
              title: 'Categorias bloqueadas',
              subtitle:
                  'Usam uma lista básica embutida de sites conhecidos. Ela não é completa: '
                  'combine com o filtro DNS familiar.',
              child: Column(
                children: <Widget>[
                  for (final WebCategory category in WebCategory.values)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(category.label),
                      value: web.blockedCategories.contains(category.code),
                      onChanged: (bool? checked) {
                        bloc.add(WebCategoryToggled(category: category, blocked: checked ?? false));
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _DomainListCard(
              title: 'Sites bloqueados',
              emptyText: 'Nenhum site bloqueado individualmente.',
              domains: web.blockedDomains,
              onAdd: (String domain) => addDomain(WebDomainList.blocked, domain),
              onRemove: (String domain) => removeDomain(WebDomainList.blocked, domain),
            ),
          ],
        ];
      },
    );
  }
}

class _DomainListCard extends StatefulWidget {
  const _DomainListCard({
    required this.title,
    required this.emptyText,
    required this.domains,
    required this.onAdd,
    required this.onRemove,
    this.emptyTone = Tone.neutral,
  });

  final String title;
  final String emptyText;
  final Tone emptyTone;
  final List<String> domains;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  State<_DomainListCard> createState() => _DomainListCardState();
}

class _DomainListCardState extends State<_DomainListCard> {
  final TextEditingController _input = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    switch (WebPolicyEditing.validateNewDomain(widget.domains, _input.text)) {
      case Ok<String>(:final String value):
        widget.onAdd(value);
        setState(() {
          _input.clear();
          _error = null;
        });
      case Err<String>(:final AppFailure failure):
        setState(() => _error = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: widget.title,
      subtitle: 'O endereço vale também para os subdomínios (www, m e outros).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _input,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    hintText: 'exemplo.com.br',
                    errorText: _error,
                    errorMaxLines: 2,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                tooltip: 'Adicionar site',
                onPressed: _add,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (widget.domains.isEmpty)
            widget.emptyTone == Tone.neutral
                ? Text(widget.emptyText, style: Theme.of(context).textTheme.bodySmall)
                : NoticeBanner(tone: widget.emptyTone, message: widget.emptyText)
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final String domain in widget.domains)
                  InputChip(
                    label: Text(domain),
                    deleteButtonTooltipMessage: 'Remover $domain',
                    onDeleted: () => widget.onRemove(domain),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
