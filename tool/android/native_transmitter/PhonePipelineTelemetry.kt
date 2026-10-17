package com.minhacamera

/** Apenas contadores e relógio monotônico; nenhuma cópia de quadro ou alocação por callback. */
internal class PhonePipelineTelemetry(private val mode: String) {
    @Volatile private var callbacks = 0L
    @Volatile private var accepted = 0L
    @Volatile private var workerStarted = 0L
    @Volatile private var published = 0L
    @Volatile private var errors = 0L
    @Volatile private var lastCallbackMs = 0L
    @Volatile private var lastAcceptedMs = 0L
    @Volatile private var lastWorkerMs = 0L
    @Volatile private var lastPublishMs = 0L
    @Volatile private var lastErrorClass = "nenhum"
    fun callback(now: Long) { callbacks++; lastCallbackMs = now }
    fun accepted(now: Long) { accepted++; lastAcceptedMs = now }
    fun worker(now: Long) { workerStarted++; lastWorkerMs = now }
    fun published(now: Long) { published++; lastPublishMs = now }
    fun failed(type: String) { errors++; lastErrorClass = type.take(55) }
    fun reset(now: Long) {
        callbacks=0; accepted=0; workerStarted=0; published=0; errors=0
        lastCallbackMs=now; lastAcceptedMs=now; lastWorkerMs=now; lastPublishMs=now
        lastErrorClass="nenhum"
    }
    fun snapshot(now: Long): String =
        "modo=$mode callbacks=$callbacks aceitos=$accepted worker=$workerStarted publicados=$published " +
        "falhas=$errors tipo=$lastErrorClass " +
        "callbackHa=${(now-lastCallbackMs).coerceAtLeast(0)}ms " +
        "aceiteHa=${(now-lastAcceptedMs).coerceAtLeast(0)}ms " +
        "workerHa=${(now-lastWorkerMs).coerceAtLeast(0)}ms " +
        "publicacaoHa=${(now-lastPublishMs).coerceAtLeast(0)}ms"
    fun publishAge(now: Long): Long = (now-lastPublishMs).coerceAtLeast(0)
}
