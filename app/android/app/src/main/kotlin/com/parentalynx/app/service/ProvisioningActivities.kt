package com.parentalynx.app.service

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.Intent
import android.os.Build
import android.os.Bundle

/**
 * Provisionamento como dono do dispositivo por QR code (Android 10 ou superior).
 *
 * Durante a configuração inicial do aparelho, o sistema pergunta ao controlador qual modo de
 * gerenciamento quer. O ParentaLynx só trabalha como dispositivo totalmente gerenciado, nunca com
 * perfil de trabalho. Ver `docs/05-device-owner.md`.
 */
class ProvisioningModeActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val result = Intent()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            result.putExtra(
                DevicePolicyManager.EXTRA_PROVISIONING_MODE,
                DevicePolicyManager.PROVISIONING_MODE_FULLY_MANAGED_DEVICE,
            )
        }
        setResult(RESULT_OK, result)
        finish()
    }
}

/**
 * Segunda etapa do provisionamento por QR code: o sistema dá ao controlador a chance de aplicar
 * as políticas antes de liberar o aparelho. As políticas do ParentaLynx dependem do vínculo com o
 * responsável, feito depois dentro do app, então aqui só se confirma.
 */
class PolicyComplianceActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_OK, Intent())
        finish()
    }
}
