import '../../../../core/utils/observable_value.dart';
import '../../domain/entities/link_state.dart';
import '../../domain/repositories/i_link_state_repository.dart';

/// Situacao do vinculo em memoria. Cada abertura do app comeca desconhecida e e resolvida com
/// o agente nativo, que guarda o vinculo de verdade.
class LinkStateRepository implements ILinkStateRepository {
  LinkStateRepository();

  final ObservableValue<LinkState> _state = ObservableValue<LinkState>.seeded(LinkState.initial);

  @override
  LinkState get current => _state.value;

  @override
  Stream<LinkState> watch() => _state.stream;

  @override
  void update(LinkState state) => _state.add(state);
}
