# ProGuard rules for Zulip Flutter

# Keep rules for React Native and Facebook dependencies
-dontwarn com.facebook.imagepipeline.nativecode.WebpTranscoder
-dontwarn com.facebook.imagepipeline.nativecode.**

# Keep Jitsi Meet SDK classes
-keep class org.jitsi.meet.** { *; }
-keep class com.facebook.react.** { *; }
-keepclassmembers class com.facebook.react.** { *; }

# Keep WebRTC
-keep class org.webrtc.** { *; }
