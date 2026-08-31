# R8 keep rules for the OutAbout release build.
#
# minifyEnabled/shrinkResources are on, so anything resolved reflectively has to
# be named here or it is stripped and fails at runtime rather than at build time.

# --- Flutter engine and embedding -------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- OneSignal ---------------------------------------------------------------
# Receivers, services and notification payload models are instantiated by name.
-keep class com.onesignal.** { *; }
-keep class com.onesignal.**$* { *; }
-dontwarn com.onesignal.**

# --- Firebase / Play services (pulled in by OneSignal for FCM) ---------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# --- Baseflow plugins: geolocator, geocoding, permission_handler -------------
-keep class com.baseflow.** { *; }
-dontwarn com.baseflow.**

# --- device_calendar_plus ----------------------------------------------------
-keep class com.builttoroam.devicecalendar.** { *; }
-dontwarn com.builttoroam.devicecalendar.**

# --- home_widget -------------------------------------------------------------
-keep class es.antonborri.home_widget.** { *; }
-dontwarn es.antonborri.home_widget.**

# --- Parcelables -------------------------------------------------------------
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# --- Kotlin coroutines -------------------------------------------------------
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-dontwarn kotlinx.coroutines.**

# --- Reflection metadata -----------------------------------------------------
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# --- Readable stack traces in the Play Console -------------------------------
# Deobfuscation still requires uploading the mapping file; Play does this
# automatically for App Bundles built by the Flutter tool.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
