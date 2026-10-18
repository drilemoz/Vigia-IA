package com.vigiaia.app

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import java.net.Inet4Address
import java.net.NetworkInterface

/** Descoberta pontual: identifica SOMENTE uma sub-rede LAN, nunca a rede celular. */
internal class LanScanSupport(context: Context) {
    private val app = context.applicationContext
    private val wifiManager = app.getSystemService(Context.WIFI_SERVICE) as? WifiManager
    private var multicastLock: WifiManager.MulticastLock? = null

    @Synchronized fun multicast(enabled: Boolean): Boolean {
        if (!enabled) {
            try { multicastLock?.let { if (it.isHeld) it.release() } } catch (_: Exception) { }
            multicastLock = null
            return true
        }
        return try {
            if (multicastLock == null) {
                multicastLock = wifiManager?.createMulticastLock("VigiaIA-LanScan")?.apply {
                    setReferenceCounted(false)
                }
            }
            if (multicastLock?.isHeld != true) multicastLock?.acquire()
            multicastLock?.isHeld == true
        } catch (_: Exception) { false }
    }

    private fun ipLong(bytes: ByteArray): Long = bytes.fold(0L) {
        value, byte -> (value shl 8) or (byte.toLong() and 255L)
    }
    private fun ipString(value: Long): String = (3 downTo 0).joinToString(".") {
        ((value ushr (it * 8)) and 255L).toString()
    }

    fun range(): Map<String, Any?> {
        val connectivity = app.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        var ip: Long? = null
        var prefix = 24
        try {
            val wifi = connectivity?.allNetworks?.firstOrNull { network ->
                connectivity?.getNetworkCapabilities(network)?.hasTransport(
                    NetworkCapabilities.TRANSPORT_WIFI) == true
            }
            val address = wifi?.let { connectivity?.getLinkProperties(it) }?.linkAddresses?.firstOrNull {
                it.address is Inet4Address && !it.address.isLoopbackAddress &&
                    !it.address.isLinkLocalAddress
            }
            if (address != null) {
                ip = ipLong(address.address.address)
                prefix = address.prefixLength
            }
        } catch (_: Exception) { }
        if (ip == null) {
            // Wi-Fi em modo hotspot pode não aparecer em allNetworks.
            try {
                val interfaces = NetworkInterface.getNetworkInterfaces()
                while (interfaces != null && interfaces.hasMoreElements() && ip == null) {
                    val device = interfaces.nextElement()
                    val name = device.name.lowercase()
                    if (!device.isUp || !listOf("wlan", "ap", "swlan", "softap").any { name.startsWith(it) }) continue
                    val addresses = device.interfaceAddresses
                    val selected = addresses.firstOrNull {
                        it.address is Inet4Address && !it.address.isLoopbackAddress &&
                            !it.address.isLinkLocalAddress
                    }
                    if (selected != null) {
                        ip = ipLong(selected.address.address)
                        prefix = selected.networkPrefixLength.toInt()
                    }
                }
            } catch (_: Exception) { }
        }
        val local = ip ?: return mapOf("hosts" to emptyList<String>(), "error" to
            "Sem IPv4 Wi-Fi ou hotspot. Conecte-se à rede local e autorize o acesso à rede.")
        if (prefix !in 1..30) return mapOf("hosts" to emptyList<String>(),
            "error" to "Máscara da rede não suportada: /$prefix")
        val mask = (0xffffffffL shl (32 - prefix)) and 0xffffffffL
        val network = local and mask
        val broadcast = network or (mask.inv() and 0xffffffffL)
        var first = network + 1
        var last = broadcast - 1
        val limited = last - first + 1 > 254
        if (limited) {
            val local24 = local and 0xffffff00L
            first = maxOf(first, local24 + 1)
            last = minOf(last, local24 + 254)
        }
        val hosts = if (last >= first) (first..last)
            .filter { it != local }.map(::ipString) else emptyList()
        return mapOf(
            "hosts" to hosts,
            "local" to ipString(local),
            "broadcast" to ipString(if (limited) (local and 0xffffff00L) + 255L else broadcast),
            "description" to "${ipString(network)}/$prefix" + if (limited) " (TCP limitado ao /24 local)" else "",
            "limited" to limited,
        )
    }
}
