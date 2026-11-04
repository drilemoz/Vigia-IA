package com.vigiaia.app

fun main() {
    for (reason in listOf(3, 4, 5, 6, 7, 9)) check(DiagnosticPolicy.exitProblem(reason) != null)
    for (reason in listOf(0, 1, 2, 8, 10, 11, 12, 13, 14, 15, 16, 99)) check(DiagnosticPolicy.exitProblem(reason) == null)
    check(DiagnosticPolicy.assessExit(3, 0, 400)?.severity == "info")
    check(DiagnosticPolicy.assessExit(3, 0, 100)?.severity == "warning")
    check(DiagnosticPolicy.assessExit(4, 0, 400)?.severity == "error")
    check(DiagnosticPolicy.assessExit(6, 0, 400)?.severity == "error")
    check(DiagnosticPolicy.assessExit(2, 9, 400)?.severity == "info")
    check(DiagnosticPolicy.assessExit(2, 9, 400)?.reason?.contains("não confirmada") == true)
    check(DiagnosticPolicy.assessExit(2, 0, 400) == null)
    check(DiagnosticPolicy.assessExit(10, 0, 100) == null)
    check(DiagnosticPolicy.belongsToSession(1000, 10000, 42, 11000, 42, 12000))
    check(!DiagnosticPolicy.belongsToSession(1000, 10000, 42, 11000, 43, 12000))
    check(!DiagnosticPolicy.belongsToSession(1000, 10000, 42, 900, 42, 12000))
    check(!DiagnosticPolicy.belongsToSession(1000, 10000, 42, 999999, 42, 12000))
    check(!DiagnosticPolicy.belongsToSession(1000, 300000, 42, 2000, 42, 400000))
    check(DiagnosticPolicy.belongsToSession(1000, 10000, -1, 11000, 43, 12000)) // legacy session
    val anr = DiagnosticPolicy.anrMethods("secretHeader=neverInclude\n\"main\" tid=1\n  at com.example.App.render(App.kt:42)\nprivatePayload=neverInclude")
    check(anr.contains("App.render"))
    check(!anr.contains("neverInclude"))
    val secret = "fictionalSecret@987"
    val legacy = "FormatException: Invalid character (at character 7)\ncamera:$secret\n      ^\n\n#0 Uri.replace\n#1 CameraEditor.save"
    val safe = DiagnosticPolicy.safe(legacy)
    check(!safe.contains(secret))
    check(safe.contains("#1 CameraEditor.save"))
    check(safe.contains("FormatException"))
    for (url in listOf("rtsp://camera:$secret@192.0.2.1/live", "http://example.test/?token=$secret")) {
        check(!DiagnosticPolicy.safe("connection $url failed").contains(secret))
    }
    check(!DiagnosticPolicy.safe("password='$secret' error").contains(secret))
    check(!DiagnosticPolicy.safe("\"password\": \"$secret\"").contains(secret))
    check(DiagnosticPolicy.safe("x".repeat(10000), 64).length == 64)
    check(DiagnosticPolicy.safe("MediaCodec error: frame rejected").contains("frame rejected"))
    println("PASS: exit classification, session PID correlation, signal uncertainty, redaction")
}
