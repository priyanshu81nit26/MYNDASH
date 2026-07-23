# Keep rules for R8/ProGuard release minification.
# Flutter plugin AARs bundle their own consumer-rules.pro (merged
# automatically), so most Firebase/Google plugins need nothing extra here.
# Payment-provider WebView/SDK rules were retired with payments v1.
# Add provider-specific rules only when a future checkout is activated.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes Exceptions
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn com.google.errorprone.annotations.**
