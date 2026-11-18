import '../../../device_policy/domain/entities/policy.dart';
import '../../../device_policy/domain/entities/policy_section.dart';

/// Secao "navegacao" da politica: navegador gerenciado, filtros e listas de sites.
final class WebSection implements PolicySection<WebPolicy> {
  const WebSection();

  @override
  WebPolicy read(Policy policy) => policy.web;

  @override
  Policy write(Policy policy, WebPolicy value) => policy.copyWith(web: value);
}
