package com.vigiaia.app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

/** Somente APK baixado e verificado no cache privado; nunca usa um caminho externo. */
internal object VigiaUpdateInstaller {
    private const val authoritySuffix = ".updates"
    private const val apkName = "vigiaia-update.apk"
    private const val maxBytes = 300L * 1024L * 1024L

    fun handle(activity: FlutterActivity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openReleases" -> {
                try {
                    activity.startActivity(Intent(Intent.ACTION_VIEW,
                        Uri.parse("https://github.com/drilemoz/Vigia-IA/releases")))
                    result.success(null)
                } catch (error: Exception) {
                    result.error("browser", "Não foi possível abrir o GitHub.", null)
                }
            }
            "install" -> install(activity, call, result)
            else -> result.notImplemented()
        }
    }

    private fun install(activity: FlutterActivity, call: MethodCall, result: MethodChannel.Result) {
        try {
            val expectedBuild = call.argument<Number>("expectedBuild")?.toLong()
                ?: throw IllegalArgumentException("Versão obrigatória")
            val sha256 = call.argument<String>("sha256")?.lowercase()
                ?: throw IllegalArgumentException("SHA-256 obrigatório")
            if (!sha256.matches(Regex("[a-f0-9]{64}"))) {
                throw IllegalArgumentException("SHA-256 inválido")
            }
            val apk = File(File(activity.cacheDir, "updates"), apkName)
            if (!apk.isFile || apk.length() <= 0 || apk.length() > maxBytes) {
                throw IllegalArgumentException("APK não encontrado ou tamanho inválido")
            }
            val hash = MessageDigest.getInstance("SHA-256")
            apk.inputStream().buffered().use { stream ->
                val buffer = ByteArray(32768)
                while (true) {
                    val count = stream.read(buffer)
                    if (count < 0) break
                    hash.update(buffer, 0, count)
                }
            }
            val actual = hash.digest().joinToString("") { "%02x".format(it.toInt() and 0xff) }
            if (actual != sha256) throw SecurityException("SHA-256 do APK não confere")

            @Suppress("DEPRECATION")
            val archive = activity.packageManager.getPackageArchiveInfo(
                apk.absolutePath, PackageManager.GET_SIGNING_CERTIFICATES)
                ?: throw SecurityException("APK Android inválido")
            if (archive.packageName != activity.packageName || archive.longVersionCode != expectedBuild) {
                throw SecurityException("Pacote ou versão do APK não corresponde ao Vigia IA")
            }
            @Suppress("DEPRECATION")
            val installed = activity.packageManager.getPackageInfo(
                activity.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            if (expectedBuild <= installed.longVersionCode) {
                throw SecurityException("A atualização não é mais recente que a instalação atual")
            }
            // Não tenta atualizar com certificado de assinatura diferente.
            val archiveSignatures = archive.signingInfo?.apkContentsSigners?.map { it.toCharsString() }?.toSet()
            val installedSignatures = installed.signingInfo?.apkContentsSigners?.map { it.toCharsString() }?.toSet()
            if (archiveSignatures.isNullOrEmpty() || archiveSignatures != installedSignatures) {
                throw SecurityException("Assinatura incompatível: preserve seus dados e não desinstale o aplicativo")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                !activity.packageManager.canRequestPackageInstalls()) {
                activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${activity.packageName}")))
                result.success("permission_required")
                return
            }
            val uri = FileProvider.getUriForFile(activity,
                "${activity.packageName}$authoritySuffix", apk)
            activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            })
            result.success("installer_opened")
        } catch (error: Exception) {
            result.error("update_rejected", error.message ?: "Atualização não permitida", null)
        }
    }
}
