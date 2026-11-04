package com.vigiaia.app

/** Pure rules: a missing shutdown marker is not proof of a crash. */
internal object DiagnosticPolicy {
    data class ExitAssessment(val reason: String, val severity: String)

    // On Android, REASON_SIGNALED + SIGKILL may be a low-memory kill on some
    // vendors. The OS does not prove that cause, so never call it a crash.
    fun assessExit(reason: Int, status: Int, importance: Int): ExitAssessment? = when (reason) {
        3 -> if (importance >= 400) ExitAssessment(
            "Android encerrou o processo em segundo plano por pressão de memória", "info"
        ) else ExitAssessment("Android encerrou o processo por falta de memória", "warning")
        4 -> ExitAssessment("Falha Java/Kotlin", "error")
        5 -> ExitAssessment("Falha nativa", "error")
        6 -> ExitAssessment("Aplicativo não respondeu (ANR)", "error")
        7 -> ExitAssessment("Falha ao inicializar o processo", "error")
        9 -> ExitAssessment("Android encerrou o processo por uso excessivo de recursos", "warning")
        2 -> if (status == 9) ExitAssessment(
            "Processo encerrado pelo Android (SIGKILL; causa não confirmada)", "info"
        ) else null
        else -> null // exits requested by user, self, update, permission, etc.
    }

    // Compatibility for earlier diagnostics / existing native contracts.
    fun exitProblem(reason: Int): String? = assessExit(reason, 0, 100)?.reason

    /** Correlates an Android exit with the saved process, not an unrelated run. */
    fun belongsToSession(
        startedAt: Long, updatedAt: Long, sessionPid: Int,
        exitAt: Long, exitPid: Int, now: Long
    ): Boolean {
        if (startedAt <= 0L || exitAt < startedAt || exitAt > now + 120000L) return false
        if (sessionPid > 0 && exitPid != sessionPid) return false
        // Allow minor clock adjustments and asynchronous checkpoint writes.
        if (updatedAt > 0 && exitAt + 120000L < updatedAt) return false
        return true
    }

    fun anrMethods(raw: String): String = safe(raw.lineSequence()
        .filter { it.trim().startsWith("at ") || it.startsWith("\"main\"") }
        .take(100).joinToString("\n"), 16000)

    fun safe(value: String, limit: Int = 8000): String {
        var text = value.replace(Regex("(?m)(FormatException:[^\\n]*)(?:\\n(?!#|\\s*at |\\s*$)[^\\n]*)+"), "$1\n[entrada omitida]")
        text = text.replace(Regex("(?i)(?:rtsps?|https?|wss?)://[^\\s\\\"<>]+"), "[endereço omitido]")
        text = text.replace(Regex("(?i)((?:password|passwd|senha|token|authorization|api[_-]?key|credential|userInfo|username)[\"']?\\s*[=:]\\s*)(?:\\\"[^\\\"]*\\\"|'[^']*'|[^\\s,;}]+)"), "$1[omitido]")
        return text.take(limit)
    }
}
