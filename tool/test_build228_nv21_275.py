"""APK 228: NV21 deve compilar, girar os planos Y/VU e sobreviver ao bootstrap."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'tool/android/native_transmitter/Nv21Frames.kt'
ANDROID = ROOT / 'android/app/src/main/kotlin/com/minhacamera/Nv21Frames.kt'
SERVICE = ROOT / 'tool/android/native_transmitter/PhoneCameraBackgroundService.kt'

class Nv21Build228Tests(unittest.TestCase):
    def test_class_copied_and_visible_to_compiler(self):
        self.assertTrue(SOURCE.is_file())
        self.assertTrue(ANDROID.is_file())
        self.assertEqual(SOURCE.read_bytes(), ANDROID.read_bytes())
        self.assertIn('package com.minhacamera', SOURCE.read_text())
        self.assertRegex(SOURCE.read_text(), r'object Nv21Frames\s*\{')
        self.assertIn('Nv21Frames.rotated(', SERVICE.read_text())
        self.assertIn('Nv21Frames.rotated(', (ROOT/'android/app/src/main/kotlin/com/minhacamera/PhoneCameraBackgroundService.kt').read_text())
        bootstrap = (ROOT/'tool/bootstrap_android.sh').read_text()
        self.assertIn('tool/android/native_transmitter/', bootstrap)
        self.assertIn('"$NATIVE_DIR/"', bootstrap)

    def test_rotation_y_and_interleaved_vu_kotlin(self):
        compiler = shutil.which('kotlinc')
        runtime = shutil.which('java')
        if not compiler or not runtime:
            self.skipTest('Kotlin JVM CLI indisponivel; verificar no Android CI')
        kt = r'''import com.minhacamera.Nv21Frames

fun main() {
    val data = byteArrayOf(1,2,3,4,5,6,7,8,9,10,11,12) // 4x2 NV21: Y=8, VU=4
    val id = Nv21Frames.rotated(data,4,2,0)
    check(id === data)
    val n90 = Nv21Frames.rotated(data,4,2,90)
    val n180 = Nv21Frames.rotated(data,4,2,180)
    val n270 = Nv21Frames.rotated(data,4,2,270)
    check(n90.contentEquals(byteArrayOf(5,1,6,2,7,3,8,4,9,10,11,12)))
    check(n180.contentEquals(byteArrayOf(8,7,6,5,4,3,2,1,11,12,9,10)))
    check(n270.contentEquals(byteArrayOf(4,8,3,7,2,6,1,5,11,12,9,10)))
    check(Nv21Frames.rotated(n90,2,4,270).contentEquals(data))
    check(Nv21Frames.rotated(n270,2,4,90).contentEquals(data))
    check(Nv21Frames.rotated(n180,4,2,180).contentEquals(data))
    try { Nv21Frames.rotated(byteArrayOf(1),4,2,90); error("aceitou buffer curto") } catch (_: IllegalArgumentException) {}
    try { Nv21Frames.rotated(data,4,2,45); error("aceitou angulo invalido") } catch (_: IllegalArgumentException) {}
    println("PASS: NV21 Y + VU, 0/90/180/270, reversibilidade, entradas invalidas")
}
'''
        with tempfile.TemporaryDirectory(prefix='nv21-') as temp:
            src = Path(temp)/'TestNv21.kt'; src.write_text(kt)
            jar = Path(temp)/'nv21.jar'
            subprocess.run([compiler,str(SOURCE),str(src),'-include-runtime','-d',str(jar)],check=True,timeout=60,capture_output=True,text=True)
            result = subprocess.run([runtime,'-jar',str(jar)],check=True,timeout=15,capture_output=True,text=True)
            self.assertIn('PASS: NV21',result.stdout)

if __name__ == '__main__': unittest.main()
