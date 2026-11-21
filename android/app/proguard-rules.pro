# Flutter ProGuard / R8 Hardening Rules

# Keep Flutter core classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Obfuscation & optimization
-dontwarn javax.annotation.**
-dontwarn java.awt.**
-dontwarn org.conscrypt.**
-dontwarn com.google.android.play.core.**

# Keep Flutter secure storage & crypto
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }

# Keep Geolocator & Image Picker plugins
-keep class com.baseflow.geolocator.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }

# Razorpay Android SDK Proguard Rules
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-optimizations !method/inlining/*
-keepclasseswithmembers class * {
  public void onPayment*(...);
}
-keepclassmembers class * {
  @android.webkit.JavascriptInterface <methods>;
}

# Additional Android Plugins (sqflite, speech_to_text, file_picker)
-keep class com.tekartik.sqflite.** { *; }
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Firebase Cloud Messaging & Local Notifications
-keep class com.google.firebase.messaging.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }

