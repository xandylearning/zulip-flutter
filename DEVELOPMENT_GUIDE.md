# X&Y Learning Platform - Development Guide

## Overview

This guide provides comprehensive instructions for adding new features and UI components to the X&Y Learning Platform Zulip Flutter fork without breaking existing functionality. We use a modular package structure to keep the codebase organized and maintainable.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Modular Package Structure](#modular-package-structure)
3. [Development Workflow](#development-workflow)
4. [Feature Integration Patterns](#feature-integration-patterns)
5. [UI Component Guidelines](#ui-component-guidelines)
6. [Testing Strategy](#testing-strategy)
7. [Code Style & Standards](#code-style--standards)

## Architecture Overview

### Current App Structure
```
lib/
├── api/              # Zulip API integration
├── generated/        # Auto-generated code (l10n, etc.)
├── model/            # Data models and business logic
├── notifications/    # Push notification handling
├── widgets/          # Core UI components
├── host/            # Platform-specific code
└── example/         # Example/demo code
```

### New Modular Structure
```
packages/
├── xy_core/          # Core X&Y Learning utilities
├── xy_ui/            # Reusable UI components
├── xy_features/      # Feature-specific packages
│   ├── voice_notes/
│   ├── file_sharing/
│   ├── class_tools/
│   └── assignments/
└── xy_integrations/  # Third-party integrations
```

## Modular Package Structure

### 1. Core Package (`packages/xy_core/`)

**Purpose**: Shared utilities, constants, and base classes

```
packages/xy_core/
├── lib/
│   ├── constants/
│   │   ├── colors.dart          # Brand colors
│   │   ├── dimensions.dart      # Spacing, sizes
│   │   └── animations.dart      # Animation constants
│   ├── utils/
│   │   ├── logger.dart          # Logging utilities
│   │   ├── validators.dart      # Form validation
│   │   └── formatters.dart      # Text formatting
│   ├── services/
│   │   ├── analytics.dart       # Analytics service
│   │   ├── storage.dart         # Local storage
│   │   └── permissions.dart     # Device permissions
│   └── models/
│       ├── user_profile.dart    # Extended user model
│       └── learning_data.dart   # Educational data models
├── pubspec.yaml
└── README.md
```

### 2. UI Package (`packages/xy_ui/`)

**Purpose**: Reusable UI components with X&Y branding

```
packages/xy_ui/
├── lib/
│   ├── atoms/                   # Basic UI elements
│   │   ├── xy_button.dart
│   │   ├── xy_text_field.dart
│   │   ├── xy_avatar.dart
│   │   └── xy_loading.dart
│   ├── molecules/               # Component combinations
│   │   ├── xy_chat_bubble.dart
│   │   ├── xy_date_separator.dart
│   │   ├── xy_message_input.dart
│   │   └── xy_file_preview.dart
│   ├── organisms/               # Complex components
│   │   ├── xy_chat_list.dart
│   │   ├── xy_class_header.dart
│   │   └── xy_assignment_card.dart
│   ├── themes/
│   │   ├── xy_theme.dart        # Main theme
│   │   ├── xy_colors.dart       # Color system
│   │   └── xy_typography.dart   # Text styles
│   └── animations/
│       ├── slide_animations.dart
│       ├── fade_animations.dart
│       └── hero_animations.dart
├── pubspec.yaml
└── README.md
```

### 3. Feature Packages (`packages/xy_features/`)

Each feature gets its own package for complete isolation.

#### Example: Voice Notes Feature
```
packages/xy_features/voice_notes/
├── lib/
│   ├── models/
│   │   └── voice_note.dart
│   ├── services/
│   │   ├── audio_recorder.dart
│   │   ├── audio_player.dart
│   │   └── voice_note_api.dart
│   ├── widgets/
│   │   ├── voice_recorder.dart
│   │   ├── voice_player.dart
│   │   └── waveform_widget.dart
│   ├── pages/
│   │   └── voice_notes_page.dart
│   └── voice_notes.dart         # Main export file
├── test/
├── pubspec.yaml
└── README.md
```

## Development Workflow

### Adding a New Feature

1. **Create Feature Package**
   ```bash
   mkdir -p packages/xy_features/new_feature
   cd packages/xy_features/new_feature
   flutter create --template=package .
   ```

2. **Setup Package Structure**
   ```yaml
   # pubspec.yaml
   name: xy_new_feature
   description: Description of your new feature
   version: 1.0.0

   environment:
     sdk: '>=3.10.0 <4.0.0'
     flutter: ">=3.33.0"

   dependencies:
     flutter:
       sdk: flutter
     xy_core:
       path: ../../xy_core
     xy_ui:
       path: ../../xy_ui
   ```

3. **Implement Feature**
   - Follow atomic design principles
   - Use XY brand components from `xy_ui`
   - Implement proper error handling
   - Add comprehensive tests

4. **Integration**
   ```yaml
   # Main app pubspec.yaml
   dependencies:
     xy_new_feature:
       path: packages/xy_features/new_feature
   ```

### Adding UI Components

1. **Choose Component Level**
   - **Atom**: Basic elements (buttons, inputs)
   - **Molecule**: Simple combinations (search bar, card)
   - **Organism**: Complex sections (chat list, header)

2. **Follow Brand Guidelines**
   ```dart
   // Use brand constants
   import 'package:xy_core/constants/colors.dart';
   import 'package:xy_core/constants/dimensions.dart';

   Container(
     decoration: BoxDecoration(
       gradient: XYColors.primaryGradient,
       borderRadius: BorderRadius.circular(XYDimensions.borderRadius),
     ),
   )
   ```

3. **Create Comprehensive Widget**
   ```dart
   class XYCustomButton extends StatelessWidget {
     const XYCustomButton({
       super.key,
       required this.onPressed,
       required this.label,
       this.isLoading = false,
       this.variant = XYButtonVariant.primary,
     });

     final VoidCallback? onPressed;
     final String label;
     final bool isLoading;
     final XYButtonVariant variant;

     @override
     Widget build(BuildContext context) {
       return Container(
         // Implementation with XY branding
       );
     }
   }
   ```

## Feature Integration Patterns

### 1. Navigation Integration

```dart
// Register feature routes
class XYRoutes {
  static const String voiceNotes = '/voice-notes';
  static const String assignments = '/assignments';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case voiceNotes:
        return MaterialPageRoute(
          builder: (_) => const VoiceNotesPage(),
        );
      // Add more routes
    }
  }
}
```

### 2. State Management Integration

```dart
// Feature-specific provider
class VoiceNotesProvider extends ChangeNotifier {
  final VoiceNoteService _service;

  VoiceNotesProvider(this._service);

  // State management logic
}

// Register in main app
void main() {
  runApp(
    MultiProvider(
      providers: [
        // Core providers
        ChangeNotifierProvider(create: (_) => VoiceNotesProvider()),
        // Add feature providers
      ],
      child: const XYApp(),
    ),
  );
}
```

### 3. API Integration

```dart
// Extend base API client
class VoiceNoteApi extends BaseApiClient {
  Future<List<VoiceNote>> getVoiceNotes(String conversationId) async {
    final response = await get('/api/voice-notes/$conversationId');
    return (response.data as List)
        .map((json) => VoiceNote.fromJson(json))
        .toList();
  }
}
```

### 4. Database Integration

```dart
// Extend existing database
extension VoiceNoteQueries on Database {
  Future<List<VoiceNote>> getVoiceNotes(String conversationId) {
    return select(voiceNotes)
        .where((note) => note.conversationId.equals(conversationId))
        .get();
  }
}
```

## UI Component Guidelines

### Brand Consistency

1. **Colors**: Always use `XYColors` constants
   ```dart
   // Good
   color: XYColors.primaryBlue

   // Bad
   color: Color(0xFF414d75)
   ```

2. **Typography**: Use branded text styles
   ```dart
   // Good
   Text('Hello', style: XYTextStyles.bodyMedium)

   // Bad
   Text('Hello', style: TextStyle(fontSize: 14))
   ```

3. **Spacing**: Use consistent dimensions
   ```dart
   // Good
   padding: XYDimensions.paddingMedium

   // Bad
   padding: EdgeInsets.all(16)
   ```

### Component Structure

```dart
class XYComponentName extends StatelessWidget {
  // 1. Constructor with required parameters first
  const XYComponentName({
    super.key,
    required this.requiredParam,
    this.optionalParam,
  });

  // 2. Final properties
  final String requiredParam;
  final String? optionalParam;

  // 3. Build method
  @override
  Widget build(BuildContext context) {
    return Container(
      // Implementation
    );
  }

  // 4. Private helper methods
  Widget _buildHelper() {
    return Container();
  }
}
```

### Animation Guidelines

```dart
class AnimatedXYButton extends StatefulWidget {
  @override
  State<AnimatedXYButton> createState() => _AnimatedXYButtonState();
}

class _AnimatedXYButtonState extends State<AnimatedXYButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: XYAnimations.defaultDuration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: XYAnimations.defaultCurve,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

## Testing Strategy

### Package-Level Testing

```dart
// packages/xy_features/voice_notes/test/voice_notes_test.dart
void main() {
  group('VoiceNotesService', () {
    late VoiceNotesService service;

    setUp(() {
      service = VoiceNotesService();
    });

    testWidgets('should record audio', (tester) async {
      // Test implementation
    });
  });
}
```

### Integration Testing

```dart
// integration_test/feature_integration_test.dart
void main() {
  group('Voice Notes Integration', () {
    testWidgets('should integrate with chat', (tester) async {
      // Integration test
    });
  });
}
```

### Widget Testing

```dart
// test/widgets/xy_button_test.dart
void main() {
  testWidgets('XYButton should show loading state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: XYButton(
          onPressed: () {},
          label: 'Test',
          isLoading: true,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

## Code Style & Standards

### File Naming
- **Widgets**: `xy_widget_name.dart`
- **Services**: `service_name_service.dart`
- **Models**: `model_name.dart`
- **Tests**: `*_test.dart`

### Import Organization
```dart
// 1. Dart SDK imports
import 'dart:async';
import 'dart:io';

// 2. Flutter imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. Third-party package imports
import 'package:provider/provider.dart';

// 4. App imports (alphabetical)
import 'package:xy_core/constants/colors.dart';
import 'package:xy_ui/atoms/xy_button.dart';

// 5. Relative imports
import '../models/voice_note.dart';
```

### Documentation Standards

```dart
/// A custom button widget that follows X&Y Learning Platform design guidelines.
///
/// This widget provides consistent styling and behavior across the app.
///
/// Example usage:
/// ```dart
/// XYButton(
///   onPressed: () => print('Pressed'),
///   label: 'Submit',
///   variant: XYButtonVariant.primary,
/// )
/// ```
class XYButton extends StatelessWidget {
  /// Creates an X&Y branded button.
  ///
  /// The [onPressed] and [label] parameters are required.
  const XYButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.variant = XYButtonVariant.primary,
  });

  /// Callback function called when the button is pressed.
  final VoidCallback? onPressed;

  /// The text to display on the button.
  final String label;
}
```

## Example: Adding Voice Notes Feature

### Step 1: Create Package Structure
```bash
mkdir -p packages/xy_features/voice_notes
cd packages/xy_features/voice_notes
flutter create --template=package .
```

### Step 2: Define Models
```dart
// lib/models/voice_note.dart
class VoiceNote {
  const VoiceNote({
    required this.id,
    required this.messageId,
    required this.duration,
    required this.filePath,
    required this.waveform,
    this.isPlaying = false,
  });

  final String id;
  final String messageId;
  final Duration duration;
  final String filePath;
  final List<double> waveform;
  final bool isPlaying;
}
```

### Step 3: Create Service
```dart
// lib/services/voice_recorder_service.dart
class VoiceRecorderService {
  Future<VoiceNote> recordVoice() async {
    // Implementation
  }

  Future<void> playVoice(VoiceNote note) async {
    // Implementation
  }
}
```

### Step 4: Build UI Components
```dart
// lib/widgets/voice_recorder_widget.dart
class VoiceRecorderWidget extends StatefulWidget {
  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
  });

  final Function(VoiceNote) onRecordingComplete;

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}
```

### Step 5: Integration
```dart
// lib/voice_notes.dart - Main export file
export 'models/voice_note.dart';
export 'services/voice_recorder_service.dart';
export 'widgets/voice_recorder_widget.dart';
```

### Step 6: Add to Main App
```yaml
# pubspec.yaml
dependencies:
  xy_voice_notes:
    path: packages/xy_features/voice_notes
```

```dart
// lib/widgets/compose_box.dart
import 'package:xy_voice_notes/voice_notes.dart';

class ComposeBox extends StatelessWidget {
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Existing components
        IconButton(
          icon: Icon(Icons.mic),
          onPressed: () => _showVoiceRecorder(context),
        ),
      ],
    );
  }

  void _showVoiceRecorder(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => VoiceRecorderWidget(
        onRecordingComplete: (note) {
          // Handle voice note
        },
      ),
    );
  }
}
```

## Best Practices

### ✅ Do's
- Use the modular package structure for all new features
- Follow atomic design principles for UI components
- Always use brand constants from `xy_core`
- Write comprehensive tests for each package
- Document all public APIs
- Use meaningful commit messages
- Create feature flags for experimental features

### ❌ Don'ts
- Don't add features directly to the main app lib folder
- Don't hardcode colors, dimensions, or animations
- Don't skip tests for new components
- Don't break existing functionality
- Don't ignore accessibility guidelines
- Don't use deprecated Flutter APIs

## Troubleshooting

### Common Issues

1. **Package Not Found**
   ```
   Error: Package xy_new_feature not found
   ```
   Solution: Check path in pubspec.yaml and run `flutter pub get`

2. **Circular Dependencies**
   ```
   Error: Circular dependency detected
   ```
   Solution: Restructure imports and dependencies

3. **Theme Issues**
   ```
   Error: XYColors not found in context
   ```
   Solution: Ensure proper theme provider setup

### Debug Commands
```bash
# Check dependencies
flutter pub deps

# Clean and rebuild
flutter clean && flutter pub get

# Run specific tests
flutter test packages/xy_features/voice_notes/test/

# Analyze code
flutter analyze packages/xy_features/voice_notes/
```

---

This guide ensures your X&Y Learning Platform remains maintainable and scalable as new features are added. Always refer to this document before implementing new functionality.