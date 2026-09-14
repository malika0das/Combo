# ── Flutter engine & embedding ────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ── Google Mobile Ads (GMA SDK 25.x + UMP 4.x) ─────────────────────────────
# The ads SDK uses reflection and ProGuard can strip the classes it loads at
# runtime via Class.forName.  Keep every public/protected class & method so
# that ad mediation adapters, consent forms, and the GMA init path work.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.internal.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-dontwarn com.google.android.gms.ads.**
-dontwarn com.google.android.gms.internal.ads.**
-dontwarn com.google.android.ump.**
-dontwarn com.google.android.gms.common.**
-dontwarn com.google.android.gms.dynamic.**

# ── Play Core / Play Feature Delivery (used by GMA internally) ────────────────
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ── Kotlin coroutines (used by UMP consent flow) ─────────────────────────────
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# ── webview_flutter_android ───────────────────────────────────────────────────
-keep class io.flutter.plugins.webviewflutter.** { *; }
-keep class android.webkit.** { *; }

# ── shared_preferences ────────────────────────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ── connectivity_plus ─────────────────────────────────────────────────────────
-keep class io.flutter.plugins.connectivity.** { *; }

# ── share_plus ────────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.shareplus.** { *; }

# ── package_info_plus ─────────────────────────────────────────────────────────
-keep class io.flutter.plugins.packageinfo.** { *; }

# ── Desugaring support (coreLibraryDesugaring) ───────────────────────────────
-keep class java.util.concurrent.Flow$** { *; }
-keep class java.util.concurrent.Flow { *; }
-dontwarn java.util.concurrent.Flow**

# ── Generic: don't warn about missing annotations / javax / sun ───────────────
-dontwarn javax.annotation.**
-dontwarn sun.misc.Unsafe
