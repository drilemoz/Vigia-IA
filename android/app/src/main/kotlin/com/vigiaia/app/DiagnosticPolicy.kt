package com.vigiaia.app

/** Pure rules: an absent clean-shutdown marker is NOT evidence of a crash. */
internal object DiagnosticPolicy {
    fun exitProblem(reason: Int): String? = when (reason) {
        3 -> "Android encerrou o processo por falta de memória"
        4 -> "Falha Java/Kotlin"
        5 -> "Falha nativa"
        6 -> "Aplicativo não respondeu (ANR)"
        7 -> "Falha ao inicializar o processo"
        9 -> "Android encerrou o processo por uso excessivo de recursos"
        else -> null // normal, user-requested, update, permission change, unknown/signal
    }

    fun anrMethods(raw: String): String = safe(raw.lineSequence()
        .filter { it.trim().startsWith("at ") || it.startsWith("\"main\"") }
        .take(100).joinToString("\n"), 16000)

    fun safe(value: String, limit: Int = 8000): String {
        // Also scrub legacy Dart FormatException source lines (bare user:password).
        var text = value.replace(Regex("(?m)(FormatException:[^\\n]*)(?:\\n(?!#|\\s*at |\\s*$)[^\\n]*)+"), "$1\n[entrada omitida]")
        text = text.replace(Regex("(?i)(?:rtsps?|https?|wss?)://[^\\s\\\"<>]+"), "[endereço omitido]")
        text = text.replace(Regex("(?i)((?:password|passwd|senha|token|authorization|api[_-]?key|credential|userInfo|username)[\"']?\\s*[=:]\\s*)(?:\\\"[^\\\"]*\\\"|'[^']*'|[^\\s,;}]+)"), "$1[omitido]")
        return text.take(limit)
    }
}
