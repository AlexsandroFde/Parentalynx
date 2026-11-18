import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/presentation/widgets/rule_editor_scaffold.dart';
import '../../domain/services/web_policy_editing.dart';
import '../bloc/web_filter/web_filter_bloc.dart';

const List<HelpTopic> _webHelp = <HelpTopic>[
  HelpTopic(
    title: 'O que o ParentaLynx vê da navegação?',
    body:
        'Só o que é aberto no navegador ParentaLynx: o endereço, o título e o horário das '
        'páginas, se o histórico estiver ligado. O que é aberto em outros navegadores e apps '
        'não é visto nem filtrado.',
  ),
  HelpTopic(
    title: 'O que é o filtro familiar?',
    body:
        'Um serviço de endereços que recusa sites de conteúdo adulto e sites maliciosos. Ele '
        'completa as categorias, que usam uma lista básica de sites conhecidos.',
  ),
  HelpTopic(
    title: 'Lista de bloqueio ou só autorizados?',
    body:
        'Na lista de bloqueio tudo abre, menos o que você bloquear. Em só autorizados, nada '
        'abre além dos sites da sua lista: bom para crianças menores.',
  ),
];

/// Regras de navegacao na internet: navegador gerenciado, filtros e listas de sites.
///
/// Espera um [WebFilterBloc] acima na arvore, ja iniciado para [device].
class WebRulesPage extends StatelessWidget {
  const WebRulesPage({required this.device, super.key});

  final ChildDevice device;

  void _removeDomain(BuildContext context, WebDomainList list, String domain) {
    final WebFilterBloc bloc = context.read<WebFilterBloc>();
    bloc.add(WebDomainRemoved(list: list, domain: domain));
    showAppSnackBar(
      context,
      '$domain saiu da lista.',
      actionLabel: 'Desfazer',
      onAction: () => bloc.add(WebDomainAdded(list: list, domain: domain)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WebFilterBloc bloc = context.read<WebFilterBloc>();
    final bool managed = device.managementMode == DeviceManagementMode.deviceOwner;
    final String name = device.displayName;
    return RuleEditorScaffold<WebFilterBloc, WebPolicy>(
      title: 'Navegação na internet',
      description: 'Como $name navega e o que fica de fora.',
      device: device,
      helpTopics: _webHelp,
      onSave: () => bloc.add(const WebFilterSaveRequested()),
      onDiscard: () => bloc.add(const WebFilterDiscardRequested()),
      onRetry: () => bloc.add(WebFilterStarted(device.id)),
      onRestoreRejected: () => bloc.add(const WebFilterRejectedChangesRestored()),
      children: (BuildContext context, WebPolicy web) {
        final bool browser = web.managedBrowser;
        return <Widget>[
          AppBanner(
            icon: AppIcons.web,
            message:
                'Só a navegação no navegador ParentaLynx é filtrada e registrada. Para $name usar '
                'só ele, bloqueie os outros navegadores.',
            actionLabel: 'Ver navegadores instalados',
            onAction: () => context.push(RulesPaths.appsInCategory('browser')),
          ),
          const SectionGap(),
          AppSection(
            title: 'Navegador ParentaLynx',
            child: AppListGroup(
              footer: browser
                  ? null
                  : 'O histórico e a busca segura dependem do navegador ParentaLynx.',
              children: <Widget>[
                AppSwitchRow(
                  icon: AppIcons.webAllowed,
                  title: 'Disponibilizar o navegador',
                  subtitle: 'Aparece no aparelho de $name como um app separado.',
                  value: browser,
                  onChanged: (bool value) => bloc.add(WebManagedBrowserChanged(value)),
                ),
                AppSwitchRow(
                  icon: AppIcons.history,
                  title: 'Registrar o histórico',
                  subtitle: 'Endereço, título e horário das páginas. $name é avisado.',
                  value: web.logHistory,
                  onChanged: browser
                      ? (bool value) => bloc.add(WebHistoryLoggingChanged(value))
                      : null,
                ),
                AppSwitchRow(
                  icon: AppIcons.search,
                  title: 'Busca segura',
                  subtitle: 'Força o modo seguro nos buscadores conhecidos.',
                  value: web.safeSearch,
                  onChanged: browser ? (bool value) => bloc.add(WebSafeSearchChanged(value)) : null,
                ),
                AppSwitchRow(
                  icon: AppIcons.verifiedUser,
                  title: 'Filtro familiar',
                  subtitle: managed
                      ? 'Recusa conteúdo adulto e sites maliciosos no aparelho inteiro.'
                      : 'Recusa conteúdo adulto e sites maliciosos no navegador ParentaLynx. No '
                            'aparelho inteiro, só no modo dispositivo gerenciado.',
                  value: web.safeDns,
                  onChanged: (bool value) => bloc.add(WebSafeDnsChanged(value)),
                ),
              ],
            ),
          ),
          const SectionGap(),
          AppSection(
            title: 'O que pode ser aberto',
            child: AppListGroup(
              dividerIndent: AppSpacing.lg + AppSizes.iconLg + AppSpacing.md,
              children: <Widget>[
                AppRadioRow<WebMode>(
                  value: WebMode.blocklist,
                  groupValue: web.mode,
                  title: 'Tudo, menos o que você bloquear',
                  subtitle: 'Os sites e as categorias bloqueadas ficam de fora.',
                  onChanged: (WebMode value) => bloc.add(WebModeChanged(value)),
                ),
                AppRadioRow<WebMode>(
                  value: WebMode.allowlist,
                  groupValue: web.mode,
                  title: 'Só os sites que você autorizar',
                  subtitle: 'Só os sites da lista de autorizados podem ser abertos.',
                  onChanged: (WebMode value) => bloc.add(WebModeChanged(value)),
                ),
              ],
            ),
          ),
          const SectionGap(),
          if (web.mode == WebMode.allowlist)
            _DomainListSection(
              title: 'Sites autorizados',
              emptyText: 'Nenhum site autorizado. Nesse modo, nada poderá ser aberto.',
              emptyTone: Tone.warning,
              domains: web.allowedDomains,
              onAdd: (String domain) {
                bloc.add(WebDomainAdded(list: WebDomainList.allowed, domain: domain));
              },
              onRemove: (String domain) => _removeDomain(context, WebDomainList.allowed, domain),
            )
          else ...<Widget>[
            AppSection(
              title: 'Categorias bloqueadas',
              subtitle:
                  'Usam uma lista básica de sites conhecidos, que não é completa. Combine com o '
                  'filtro familiar.',
              child: AppListGroup(
                dividerIndent: AppSpacing.lg + AppSizes.minTapTarget + AppSpacing.md,
                children: <Widget>[
                  for (final WebCategory category in WebCategory.values)
                    AppCheckboxRow(
                      title: category.label,
                      value: web.blockedCategories.contains(category.code),
                      onChanged: (bool checked) {
                        bloc.add(WebCategoryToggled(category: category, blocked: checked));
                      },
                    ),
                ],
              ),
            ),
            const SectionGap(),
            _DomainListSection(
              title: 'Sites bloqueados',
              emptyText: 'Nenhum site bloqueado individualmente.',
              domains: web.blockedDomains,
              onAdd: (String domain) {
                bloc.add(WebDomainAdded(list: WebDomainList.blocked, domain: domain));
              },
              onRemove: (String domain) => _removeDomain(context, WebDomainList.blocked, domain),
            ),
          ],
        ];
      },
    );
  }
}

/// Lista de sites com o campo para acrescentar (conferido antes de entrar) e a remocao.
class _DomainListSection extends StatefulWidget {
  const _DomainListSection({
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
  State<_DomainListSection> createState() => _DomainListSectionState();
}

class _DomainListSectionState extends State<_DomainListSection> {
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
    final int count = widget.domains.length;
    return AppSection(
      title: widget.title,
      subtitle: count == 0 ? null : (count == 1 ? '1 site' : '$count sites'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: _input,
                  label: 'Endereço do site',
                  hint: 'exemplo.com.br',
                  helper: 'Vale também para www e outros subdomínios.',
                  errorText: _error,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: AppIconButton(
                  icon: AppIcons.add,
                  tooltip: 'Adicionar site',
                  variant: AppIconButtonVariant.tonal,
                  onPressed: _add,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (widget.domains.isEmpty)
            widget.emptyTone == Tone.neutral
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: Text(widget.emptyText, style: context.text.bodySmall),
                  )
                : AppBanner(tone: widget.emptyTone, message: widget.emptyText)
          else
            AppListGroup(
              dividerIndent: AppSpacing.lg,
              children: <Widget>[
                for (final String domain in widget.domains)
                  AppListRow(
                    title: domain,
                    titleStyle: context.text.bodyLarge,
                    trailing: AppIconButton(
                      icon: AppIcons.removeCircle,
                      tooltip: 'Remover $domain',
                      onPressed: () => widget.onRemove(domain),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
