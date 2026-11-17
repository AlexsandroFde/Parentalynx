import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/domain/policy.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../devices/domain/device.dart';
import '../rules_paths.dart';
import 'widgets/rule_scaffold.dart';

const int _maxDomains = 500;

/// Regras de navegacao na internet: navegador gerenciado, filtros e listas de sites.
class WebRulesPage extends StatelessWidget {
  const WebRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RuleEditorScaffold(
      title: 'Navegação na internet',
      children: (BuildContext context, RuleEditing editing) {
        final WebPolicy web = editing.draft.web;
        final bool managed = editing.device.managementMode == DeviceManagementMode.deviceOwner;

        void change(WebPolicy Function(WebPolicy current) update) {
          editing.update((Policy p) => p.copyWith(web: update(p.web)));
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
                  onChanged: (bool v) => change((WebPolicy w) => w.copyWith(managedBrowser: v)),
                ),
                SwitchRow(
                  title: 'Registrar o histórico',
                  subtitle: 'Endereço, título e horário das páginas. A criança é avisada.',
                  value: web.logHistory,
                  onChanged: web.managedBrowser
                      ? (bool v) => change((WebPolicy w) => w.copyWith(logHistory: v))
                      : null,
                ),
                SwitchRow(
                  title: 'Busca segura',
                  subtitle: 'Força o modo seguro nos buscadores conhecidos.',
                  value: web.safeSearch,
                  onChanged: web.managedBrowser
                      ? (bool v) => change((WebPolicy w) => w.copyWith(safeSearch: v))
                      : null,
                ),
                SwitchRow(
                  title: 'Filtro DNS familiar',
                  subtitle: managed
                      ? 'Bloqueia conteúdo adulto e sites maliciosos no aparelho inteiro.'
                      : 'Bloqueia conteúdo adulto e sites maliciosos no navegador gerenciado. '
                            'No aparelho inteiro só é garantido no modo dispositivo gerenciado.',
                  value: web.safeDns,
                  onChanged: (bool v) => change((WebPolicy w) => w.copyWith(safeDns: v)),
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
                    change((WebPolicy w) => w.copyWith(mode: value.first));
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
              onChanged: (List<String> v) => change((WebPolicy w) => w.copyWith(allowedDomains: v)),
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
                      onChanged: (bool? checked) => change((WebPolicy w) {
                        final List<String> next = <String>[...w.blockedCategories]
                          ..remove(category.code);
                        if (checked ?? false) {
                          next.add(category.code);
                        }
                        return w.copyWith(blockedCategories: next);
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _DomainListCard(
              title: 'Sites bloqueados',
              emptyText: 'Nenhum site bloqueado individualmente.',
              domains: web.blockedDomains,
              onChanged: (List<String> v) => change((WebPolicy w) => w.copyWith(blockedDomains: v)),
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
    required this.onChanged,
    this.emptyTone = Tone.neutral,
  });

  final String title;
  final String emptyText;
  final Tone emptyTone;
  final List<String> domains;
  final ValueChanged<List<String>> onChanged;

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
    final String? domain = WebPolicy.normalizeDomain(_input.text);
    if (domain == null) {
      setState(() => _error = 'Digite um endereço válido, por exemplo exemplo.com.br');
      return;
    }
    if (widget.domains.contains(domain)) {
      setState(() => _error = 'Esse site já está na lista.');
      return;
    }
    if (widget.domains.length >= _maxDomains) {
      setState(() => _error = 'A lista chegou ao limite de $_maxDomains sites.');
      return;
    }
    widget.onChanged(<String>[...widget.domains, domain]);
    setState(() {
      _input.clear();
      _error = null;
    });
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
                    onDeleted: () => widget.onChanged(
                      widget.domains.where((String item) => item != domain).toList(),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
