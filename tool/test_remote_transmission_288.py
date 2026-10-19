"""Contratos preventivos da retomada MCRP e memória de câmera da 1.0.288.
Não substituem testes físicos de câmera, rede, consumo ou Android 14.
"""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
read=lambda path:(ROOT/path).read_text(encoding='utf-8')

class RemoteTransmission288(unittest.TestCase):
    def test_protocol_is_authenticated_and_backward_compatible(self):
        server=read('android/app/src/main/kotlin/com/minhacamera/PhoneCameraServer.kt')
        client=read('lib/services/mcrp_client.dart')
        for route in ('transmission/start','transmission/stop'):
            self.assertIn('POST $control/'+route,server)
            self.assertIn("'"+route+"'",client)
        self.assertIn('X-Transmitting:',server)
        self.assertIn("'x-transmitting'",client)
        self.assertIn('val control = wanted.replaceFirst("/live/", "/control/")',server)
        self.assertIn('changeTransmission?.invoke(transmissionAction)',server)
        self.assertIn('recording-active',server)
        self.assertIn('transmissionActive?.invoke() == false',server)
        self.assertIn('writeError(peer, 503, "Service Unavailable")',server)
        self.assertEqual(read('tool/android/native_transmitter/PhoneCameraServer.kt'),server)

    def test_pause_releases_expensive_capture_not_authentication(self):
        service=read('android/app/src/main/kotlin/com/minhacamera/PhoneCameraBackgroundService.kt')
        pause=service.split('private fun pauseRemoteCapture()',1)[1].split('private fun resumeRemoteCapture()',1)[0]
        for phrase in ('if (!running || closing || recording', 'releasePreview()', 'server?.clearFrame()',
                       'server?.clearAvc()', 'wifiLock?.release()', 'wakeLock?.release()', 'running = false'):
            self.assertIn(phrase,pause)
        self.assertNotIn('stopSelf()',pause)
        self.assertNotIn('server?.stop()',pause)
        self.assertIn('resumeRemoteCapture()',service)
        self.assertIn('server = session',service)
        self.assertIn('if (server !== session || closing || !running) return',service)
        self.assertIn('if (!closing && running && recording != desired)',service)
        self.assertEqual(read('tool/android/native_transmitter/PhoneCameraBackgroundService.kt'),service)

    def test_resume_does_not_rebind_port_or_change_token(self):
        service=read('android/app/src/main/kotlin/com/minhacamera/PhoneCameraBackgroundService.kt')
        resume=service.split('private fun resumeRemoteCapture()',1)[1].split('private fun releasePreview()',1)[0]
        self.assertIn('val session = server ?: return',resume)
        self.assertIn('openPreview(session, selectedFacing, requestedQuality, prepared)',resume)
        self.assertIn('PhoneHeadlessPreview.create(640, 480)',resume)
        self.assertIn('acquireLocks()',resume)
        self.assertNotIn('PhoneCameraServer(',resume)
        self.assertIn('lastError = "Retomada da câmera:',resume)

    def test_receiver_controls_use_actual_status_and_legacy_fallback(self):
        controls=read('lib/widgets/mcrp_remote_controls.dart')
        self.assertIn("bool get _transmittingKnown => status['x-transmitting'] == '0'",controls)
        self.assertIn('if (_transmittingKnown)',controls)
        self.assertIn("state['x-transmitting'] == expectedTransmission",controls)
        self.assertIn('Parar transmissão',controls)
        self.assertIn('if (_transmitting)',controls)
        self.assertIn("_transmitting ? 'Pausar' : 'Iniciar'", controls)
        native=read('lib/screens/native_transmitter_screen.dart')
        self.assertIn('Aguardando comando remoto',native)
        self.assertIn('if (status.url != null && !status.releasing)',native)

    def test_home_remembers_id_without_secret_and_fallback_does_not_forget(self):
        store=read('lib/services/last_live_camera_service.dart')
        home=read('lib/screens/home_screen.dart')
        nav=read('lib/screens/home_screen_redesign.dart')
        self.assertIn("jsonEncode({'cameraId': id})",store)
        self.assertNotIn('accessKey',store)
        self.assertNotIn('rtspUrl',store)
        self.assertIn('Future<void> _startRememberedCamera()',home)
        self.assertIn('final check = await _cameraRegistry.probe(selected);',home)
        self.assertIn('if (check.online)',home)
        self.assertIn('await _startLocalCamera(rememberSelection: false);',home)
        self.assertIn('rememberSelection && camera != null',home)
        self.assertIn('LastLiveCameraService.instance.readManual()',home)
        self.assertIn('NativePlatformService.instance.protectSecret',store)
        self.assertIn('NativePlatformService.instance.unprotectSecret',store)
        self.assertIn('LastLiveCameraService.instance.remember(camera.id)',home)
        self.assertIn('unawaited(_startRememberedCamera());',nav)
        self.assertIn('onTap: () => unawaited(_startRememberedCamera()),',nav)
        self.assertIn('LastLiveCameraService.instance.remember(camera.id)',read('lib/screens/monitor_screen_multicamera.dart'))

    def test_thermal_limits_preexisting_and_no_invented_savings(self):
        eco=read('android/app/src/main/kotlin/com/minhacamera/PhoneEcoPolicy.kt')
        self.assertIn('tempTenthsC >= 450',eco)
        self.assertIn('state == PhoneHeatState.HOT -> 300L',eco)
        ui=read('lib/widgets/mcrp_remote_controls.dart')
        self.assertNotIn('FPS medido:', ui)
        self.assertIn('x-battery-temp-tenths',read('lib/services/mcrp_client.dart'))
        self.assertIn('>= 420',ui)

if __name__=='__main__':unittest.main()
