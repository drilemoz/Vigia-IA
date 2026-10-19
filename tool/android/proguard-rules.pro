# Vigia IA 1.0.310: ML Kit OCR Latin (placas brasileiras).
# O plugin Flutter contem branches para scripts opcionais nao instalados.
# R8 pode encontrar essas referencias estaticas no metodo initialize().
# Somente as 8 classes ausentes confirmadas pelo APK 260 sao ignoradas.
# Nao suprimir erros genericos de ML Kit, Google ou bibliotecas Android.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
