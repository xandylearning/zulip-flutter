# Android Build Configuration

This document describes the Android build configuration for the Zulip Flutter app, particularly the setup required for compatibility with React Native dependencies (used by Jitsi Meet SDK).

## Overview

The app uses Flutter's standard build types (`debug`, `profile`, `release`), but the Jitsi Meet Flutter SDK depends on React Native, which only provides `debug` and `release` variants. This creates a build variant mismatch that must be resolved through Gradle configuration.

## Current Status

**Status**: Build configuration is being updated to resolve Jitsi Meet SDK compatibility issues.

**Last Updated**: December 2024

**Known Issues**:
- Jitsi Meet Flutter SDK (v10.2.0) has React Native dependencies that don't support `profile` build type
- React Native dependencies only provide `debug` and `release` variants
- Profile builds fail with "No matching variant" errors for React Native dependencies

## Build Configuration Files

### 1. android/build.gradle

This is the root Gradle build file that applies configuration to all subprojects.

#### Current Configuration (Updated December 2024)

```gradle
allprojects {
    repositories {
        google()
        mavenCentral()
    }

    configurations.all {
        resolutionStrategy {
            // Handle React Native dependencies that don't have profile variants
            eachDependency { details ->
                if (details.requested.group == 'com.facebook.react') {
                    // Use release variant for profile builds when available
                    if (details.requested.name == 'react-android') {
                        details.useTarget group: details.requested.group, name: details.requested.name, version: details.requested.version
                    }
                }
            }
        }
    }
}
```

**Current Status**: This configuration is being tested and may need refinement.

**Purpose**: This configuration attempts to resolve React Native dependency conflicts by:
1. Intercepting dependency resolution for React Native packages
2. Forcing the use of available variants when profile is not available
3. Applying this strategy to all subprojects

**Limitations**: This approach may not fully resolve all variant matching issues and may need additional configuration.

### 2. android/app/build.gradle

The app-level build configuration.

#### Current Build Types Configuration (Updated December 2024)

```gradle
buildTypes {
    debug {
        // Debug build type
    }
    profile {
        // Profile build type - inherits from release for React Native compatibility
        initWith release
        matchingFallbacks = ['release', 'debug']
    }
    release {
        signingConfig project.hasProperty('signed') ?
                signingConfigs.release : signingConfigs.debug
    }
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlinVersion"
}

configurations.all {
    resolutionStrategy {
        // Force React Native dependencies to use release variant for profile builds
        eachDependency { details ->
            if (details.requested.group == 'com.facebook.react' && details.requested.name == 'react-android') {
                details.useTarget group: details.requested.group, name: details.requested.name, version: details.requested.version
            }
        }
    }
}
```

**Key settings**:
- `initWith release`: Profile builds inherit settings from release builds
- `matchingFallbacks = ['release', 'debug']`: When dependencies don't have a profile variant, use release (or debug as fallback)
- Additional resolution strategy at app level to handle React Native dependencies

**Current Status**: This configuration is being tested and may need further refinement.

### 3. android/app/proguard-rules.pro

ProGuard/R8 rules for code shrinking and obfuscation.

```proguard
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
```

**Purpose**: These rules prevent R8 (Android's code shrinker) from:
1. Warning about missing optional dependencies (`-dontwarn`)
2. Removing or obfuscating classes needed by Jitsi Meet and React Native at runtime (`-keep`)

## Common Build Issues and Solutions

### Issue: "No matching variant of com.facebook.react:react-android was found"

**Symptom**: Build fails with error about BuildTypeAttr mismatch (profile vs debug/release)

**Current Status**: This issue is actively being resolved through Gradle configuration updates.

**Attempted Solutions**:
1. Added `matchingFallbacks = ['release', 'debug']` to profile build type
2. Added resolution strategy to force React Native dependencies to use available variants
3. Configured profile build type to inherit from release

**If you still see this error**:
1. Run `flutter clean`
2. Delete the `build` directory: `rm -rf build/`
3. Try building with debug instead: `flutter build apk --debug`
4. If debug works but profile doesn't, the issue is specifically with profile build type configuration

### Issue: "Missing class com.facebook.imagepipeline.nativecode.WebpTranscoder"

**Symptom**: R8 fails during minification with missing class errors

**Solution**: Add ProGuard rules to `android/app/proguard-rules.pro`:
```proguard
# Keep rules for React Native and Facebook dependencies
-dontwarn com.facebook.imagepipeline.nativecode.WebpTranscoder
-dontwarn com.facebook.imagepipeline.nativecode.**

# Keep Jitsi Meet SDK classes
-keep class org.jitsi.meet.** { *; }
-keep class com.facebook.react.** { *; }
-keepclassmembers class com.facebook.react.** { *; }

# Keep WebRTC
-keep class org.webrtc.** { *; }
```

### Issue: Profile builds work but debug builds fail

**Symptom**: Debug builds fail with Gradle configuration errors

**Solution**: Ensure all build types are properly configured in `android/app/build.gradle` and that the resolution strategy doesn't interfere with debug builds.

### Issue: Jitsi Meet SDK compatibility

**Symptom**: Various build errors related to Jitsi Meet Flutter SDK dependencies

**Current Status**: Being actively resolved through:
1. Gradle configuration updates
2. Build type fallback strategies
3. Dependency resolution overrides

**Workaround**: If profile builds continue to fail, use debug builds for development:
```bash
flutter run --debug
# or
flutter build apk --debug
```

## Build Variants

The app supports three build variants:

1. **Debug** (`flutter run` or `flutter build apk --debug`)
   - No code minification
   - Debug symbols included
   - Faster builds
   - Larger APK size

2. **Profile** (`flutter run --profile` or `flutter build apk --profile`)
   - Code minification enabled
   - Some debug capabilities retained
   - Performance profiling support
   - Medium APK size

3. **Release** (`flutter build apk --release` or `flutter build appbundle`)
   - Full code minification and obfuscation
   - Resource shrinking enabled
   - Smallest APK size
   - Production-ready

## Testing Build Configuration Changes

When modifying build configuration, test all variants:

```bash
# Clean previous builds
flutter clean

# Test debug build (most likely to work)
flutter build apk --debug

# Test profile build (currently being fixed)
flutter build apk --profile

# Test release build
flutter build apk --release
```

**Note**: As of December 2024, profile builds may still fail due to Jitsi Meet SDK compatibility issues. Debug builds should work for development purposes.

## Alternative Solutions

If the current Gradle configuration doesn't resolve the Jitsi Meet SDK compatibility issues, consider these alternatives:

### Option 1: Use Debug Builds for Development

For development and testing, use debug builds which are more likely to work:

```bash
flutter run --debug
flutter build apk --debug
```

### Option 2: Update Jitsi Meet SDK

Consider updating to a newer version of the Jitsi Meet Flutter SDK that may have better React Native compatibility:

```yaml
# In pubspec.yaml
dependencies:
  jitsi_meet_flutter_sdk: ^11.6.0  # Check for latest version
```

### Option 3: Conditional Build Configuration

Create a separate build configuration that excludes Jitsi Meet SDK for profile builds:

```gradle
// In android/app/build.gradle
android {
    buildTypes {
        profile {
            initWith release
            matchingFallbacks = ['release', 'debug']
            // Add build config field to disable Jitsi in profile builds
            buildConfigField "boolean", "ENABLE_JITSI", "false"
        }
    }
}
```

### Option 4: Use Release Builds for Performance Testing

For performance testing, use release builds instead of profile builds:

```bash
flutter build apk --release
flutter run --release
```

## References

- [Gradle Variant Matching](https://docs.gradle.org/current/userguide/variant_attributes.html)
- [Android Build Configuration](https://developer.android.com/build)
- [R8 Code Shrinking](https://developer.android.com/build/shrink-code)
- [Flutter Build Modes](https://docs.flutter.dev/testing/build-modes)
