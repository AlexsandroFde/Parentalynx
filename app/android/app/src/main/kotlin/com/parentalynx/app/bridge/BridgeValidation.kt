package com.parentalynx.app.bridge

/**
 * Validação das entradas que chegam da interface Flutter pela ponte.
 *
 * Valores fora do contrato são recusados com o código padronizado `invalid_argument`, que o
 * Dart converte em `NativeFailure` (`NativeErrorCode.invalidArgument`). Assim um erro da
 * interface aparece como recusa tipada, em vez de ser corrigido em silêncio no meio do agente.
 *
 * Códigos de erro da ponte (o mesmo catálogo de `NativeErrorCode` no Dart):
 * - `admin_auth_required`: a operação exige autenticação do responsável válida.
 * - `mode_locked`: o modo não pode ser trocado com o aparelho vinculado.
 * - `forbidden_key`: chave do armazenamento reservada ao agente nativo.
 * - `policy_invalid`: política recebida que o agente não consegue ler.
 * - `invalid_argument`: argumento fora do intervalo ou do formato aceito.
 */
internal object BridgeValidation {
    const val CODE_INVALID_ARGUMENT = "invalid_argument"

    /** Maior pedido de tempo adicional: 12 horas, o mesmo limite do tempo extra no painel. */
    const val MAX_REQUEST_MINUTES = 720L

    /** Maior liberação local pelo responsável no aparelho: 4 horas. */
    const val MAX_OVERRIDE_MINUTES = 240L

    private val PACKAGE_NAME = Regex("^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$")

    /** Minutos de um pedido de tempo. Nulo significa "o responsável decide". */
    fun requestMinutes(minutes: Long?): Int? {
        if (minutes == null) return null
        if (minutes !in 1L..MAX_REQUEST_MINUTES) throw invalid("Peça entre 1 minuto e 12 horas.")
        return minutes.toInt()
    }

    /** Minutos de uma liberação local. */
    fun overrideMinutes(minutes: Long): Int {
        if (minutes !in 1L..MAX_OVERRIDE_MINUTES) throw invalid("Libere entre 1 minuto e 4 horas.")
        return minutes.toInt()
    }

    /** Nome de pacote Android (`com.exemplo.app`). */
    fun packageName(value: String): String {
        if (!PACKAGE_NAME.matches(value)) throw invalid("Nome de pacote inválido.")
        return value
    }

    /** Chave do armazenamento seguro. */
    fun storageKey(key: String): String {
        if (key.isBlank()) throw invalid("Chave de armazenamento vazia.")
        return key
    }

    fun invalid(message: String): FlutterError = FlutterError(CODE_INVALID_ARGUMENT, message, null)
}
