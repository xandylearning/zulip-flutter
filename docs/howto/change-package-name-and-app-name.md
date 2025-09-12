# How to Change Package Name and App Name

This document provides a step-by-step guide for changing the package name and app name in a Flutter Zulip project.

## Overview

This process involves updating the package identifier from `com.zulip.flutter` to `com.dev.zulip.mobile.xandy` and changing the app display name from "Zulip" to "xandy" across all supported platforms.

## Prerequisites

- Flutter project with existing package structure
- Access to all platform-specific configuration files
- Understanding of Flutter project structure

## Step-by-Step Process

### 1. Android Configuration

#### 1.1 Update build.gradle
Update `/android/app/build.gradle`:
```gradle
android {
    namespace "com.dev.zulip.mobile.xandy"  // Changed from "com.zulip.flutter"

    defaultConfig {
        applicationId "com.dev.zulip.mobile.xandy"  // Changed from "com.zulipmobile"
        // ... other config
    }
}
```

#### 1.2 Update AndroidManifest.xml
Update `/android/app/src/main/AndroidManifest.xml`:
```xml
<application
    android:label="xandy"  <!-- Changed from "Zulip" -->
    android:name="${applicationName}"
    android:icon="@mipmap/launcher_icon">
```

#### 1.3 Restructure Kotlin Package Directory
```bash
# Create new package directory structure
mkdir -p android/app/src/main/kotlin/com/dev/zulip/mobile/xandy

# Move existing Kotlin files
mv android/app/src/main/kotlin/com/zulip/flutter/* android/app/src/main/kotlin/com/dev/zulip/mobile/xandy/

# Remove old directory
rm -rf android/app/src/main/kotlin/com/zulip
```

#### 1.4 Update Package Declarations
Update the package declaration in all Kotlin files:
```kotlin
// Change from:
package com.zulip.flutter

// To:
package com.dev.zulip.mobile.xandy
```

Files to update:
- `MainActivity.kt`
- `ZulipPlugin.kt`
- `AndroidIntentEventListener.kt`
- `AndroidIntents.g.kt`
- `AndroidNotifications.g.kt`

### 2. iOS Configuration

#### 2.1 Update Info.plist
Update `/ios/Runner/Info.plist`:
```xml
<key>CFBundleDisplayName</key>
<string>xandy</string>  <!-- Changed from "Zulip" -->

<key>CFBundleName</key>
<string>xandy</string>  <!-- Changed from "Zulip" -->

<key>CFBundleURLName</key>
<string>com.dev.zulip.mobile.xandy</string>  <!-- Changed from "org.zulip.Zulip" -->
```

#### 2.2 Update Xcode Project
Update `/ios/Runner.xcodeproj/project.pbxproj`:
```bash
# Replace all occurrences of:
PRODUCT_BUNDLE_IDENTIFIER = org.zulip.Zulip;

# With:
PRODUCT_BUNDLE_IDENTIFIER = com.dev.zulip.mobile.xandy;
```

### 3. macOS Configuration

#### 3.1 Update AppInfo.xcconfig
Update `/macos/Runner/Configs/AppInfo.xcconfig`:
```
PRODUCT_NAME = xandy  # Changed from "Zulip"
PRODUCT_BUNDLE_IDENTIFIER = com.dev.zulip.mobile.xandy  # Changed from "com.zulip.flutter"
```

### 4. Linux Configuration

#### 4.1 Update CMakeLists.txt
Update `/linux/CMakeLists.txt`:
```cmake
set(BINARY_NAME "xandy")  # Changed from "zulip"
set(APPLICATION_ID "com.dev.zulip.mobile.xandy")  # Changed from "com.zulip.flutter"
```

### 5. Windows Configuration

#### 5.1 Update CMakeLists.txt
Update `/windows/CMakeLists.txt`:
```cmake
project(xandy LANGUAGES CXX)  # Changed from "zulip"
set(BINARY_NAME "xandy")  # Changed from "zulip"
```

#### 5.2 Update main.cpp
Update `/windows/runner/main.cpp`:
```cpp
if (!window.Create(L"xandy", origin, size)) {  // Changed from L"Zulip"
```

#### 5.3 Update Runner.rc
Update `/windows/runner/Runner.rc`:
```rc
VALUE "FileDescription", "xandy" "\0"  # Changed from "zulip"
VALUE "InternalName", "xandy" "\0"  # Changed from "zulip"
VALUE "OriginalFilename", "xandy.exe" "\0"  # Changed from "zulip.exe"
VALUE "ProductName", "xandy" "\0"  # Changed from "Zulip"
```

### 6. Plugin Package Configuration

#### 6.1 Update zulip_plugin build.gradle
Update `/packages/zulip_plugin/android/build.gradle`:
```gradle
android {
    namespace "com.dev.zulip.mobile.xandy"  # Changed from "com.zulip.flutter"
}
```

#### 6.2 Restructure Plugin Kotlin Directory
```bash
# Create new package directory structure
mkdir -p packages/zulip_plugin/android/src/main/kotlin/com/dev/zulip/mobile/xandy

# Move existing Kotlin files
mv packages/zulip_plugin/android/src/main/kotlin/com/zulip/flutter/* packages/zulip_plugin/android/src/main/kotlin/com/dev/zulip/mobile/xandy/

# Remove old directory
rm -rf packages/zulip_plugin/android/src/main/kotlin/com/zulip
```

#### 6.3 Update Plugin Package Declaration
Update `/packages/zulip_plugin/android/src/main/kotlin/com/dev/zulip/mobile/xandy/ZulipShimPlugin.kt`:
```kotlin
package com.dev.zulip.mobile.xandy  # Changed from "com.zulip.flutter"
```

#### 6.4 Update Plugin pubspec.yaml
Update `/packages/zulip_plugin/pubspec.yaml`:
```yaml
android:
  package: com.dev.zulip.mobile.xandy  # Changed from "com.zulip.flutter"
  pluginClass: ZulipShimPlugin
```

### 7. Pigeon Configuration

#### 7.1 Update android_notifications.dart
Update `/pigeon/android_notifications.dart`:
```dart
PigeonOptions(
  dartOut: 'lib/host/android_notifications.g.dart',
  kotlinOut: 'android/app/src/main/kotlin/com/dev/zulip/mobile/xandy/AndroidNotifications.g.kt',  # Updated path
  kotlinOptions: KotlinOptions(package: 'com.dev.zulip.mobile.xandy'),  # Updated package
))
```

#### 7.2 Update android_intents.dart
Update `/pigeon/android_intents.dart`:
```dart
PigeonOptions(
  dartOut: 'lib/host/android_intents.g.dart',
  kotlinOut: 'android/app/src/main/kotlin/com/dev/zulip/mobile/xandy/AndroidIntents.g.kt',  # Updated path
  kotlinOptions: KotlinOptions(
    package: 'com.dev.zulip.mobile.xandy',  # Updated package
    // ... other options
  ),
))
```

### 8. Code References

#### 8.1 Update Store Comments
Update `/lib/model/store.dart`:
```dart
// Change comment from:
//     on Linux, -> "${XDG_DATA_HOME:-~/.local/share}/com.zulip.flutter/"

// To:
//     on Linux, -> "${XDG_DATA_HOME:-~/.local/share}/com.dev.zulip.mobile.xandy/"
```

#### 8.2 Update Test Files
Update `/test/model/store_test.dart`:
```dart
// Replace all occurrences of:
'com.zulip.flutter'

// With:
'com.dev.zulip.mobile.xandy'
```

## Post-Change Steps

### 1. Regenerate Pigeon Files
After updating the Pigeon configuration, regenerate the platform-specific files:
```bash
flutter packages pub run pigeon --input pigeon/android_notifications.dart
flutter packages pub run pigeon --input pigeon/android_intents.dart
```

### 2. Clean and Rebuild
```bash
flutter clean
flutter pub get
flutter build android  # Test Android build
flutter build ios      # Test iOS build (if on macOS)
```

### 3. Verify Changes
- Check that the app name appears as "xandy" in device settings
- Verify package name in app store listings
- Test deep linking with new package name
- Ensure notifications work with new package identifier

## Important Notes

### Production Considerations
1. **App Store Updates**: Changing package names may require creating a new app listing
2. **User Data**: Existing user data may not migrate automatically
3. **Deep Links**: Update any external deep links to use new package name
4. **Push Notifications**: Update FCM/APNS configuration for new package name
5. **Signing**: May need new signing certificates for new package name

### Backup Recommendations
1. Create a full backup of the project before making changes
2. Test changes in a development environment first
3. Document any custom configurations that might be affected

### Platform-Specific Notes
- **Android**: Package name changes require uninstalling and reinstalling the app
- **iOS**: Bundle identifier changes may require new provisioning profiles
- **macOS**: May need to update code signing settings
- **Windows**: Executable name changes affect shortcuts and file associations

## Troubleshooting

### Common Issues
1. **Build Failures**: Ensure all package references are updated consistently
2. **Missing Files**: Verify all Kotlin files are moved to new directory structure
3. **Plugin Errors**: Regenerate Pigeon files after configuration changes
4. **Signing Issues**: Update signing configuration for new package names

### Verification Commands
```bash
# Check for remaining old package references
grep -r "com.zulip.flutter" . --exclude-dir=build --exclude-dir=.git

# Check for remaining old app names
grep -r "Zulip" . --exclude-dir=build --exclude-dir=.git

# Verify new package structure
find android/app/src/main/kotlin -name "*.kt" | head -10
```

## Summary

This process changes:
- **Package Name**: `com.zulip.flutter` → `com.dev.zulip.mobile.xandy`
- **App Name**: "Zulip" → "xandy"

The changes affect all supported platforms (Android, iOS, macOS, Linux, Windows) and require careful coordination to maintain consistency across the entire project.

