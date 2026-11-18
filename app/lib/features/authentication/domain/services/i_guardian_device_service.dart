/// Informacoes deste aparelho que identificam a sessao do responsavel.
abstract interface class IGuardianDeviceService {
  /// Nome amigavel do aparelho, com um padrao quando o sistema nao informa.
  Future<String> deviceName();
}
