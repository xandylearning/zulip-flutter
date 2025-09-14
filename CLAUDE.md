# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Testing and Linting
- **Run all tests and checks**: `tools/check`
- **Run specific test suites**: `tools/check analyze test` or `tools/check android`
- **Run single test file**: `flutter test test/foo/bar_test.dart --name 'baz'`
- **Analyze code (type-checking and linting)**: `flutter analyze`
- **Run all unit tests**: `flutter test`

### Code Generation
- **Generate API types**: `dart run build_runner build --delete-conflicting-outputs`
- **Watch for changes**: `dart run build_runner watch --delete-conflicting-outputs`
- **Generate translations**: `flutter gen-l10n`
- **Generate database schema**: `dart run drift_dev schema dump lib/model/database.dart test/model/schemas/`

### Building
- **Run app**: `flutter run`
- **Build APK**: `flutter build apk`
- **Build app bundle**: `flutter build appbundle`

## Project Architecture

### Core Architecture
This is a Flutter app for the Zulip chat platform, supporting Android and iOS. The app uses a layered architecture:

**State Management**:
- Global state managed through `GlobalStore` class in `lib/model/store.dart`
- Uses `TestGlobalStore` for testing with `TestZulipBinding`
- State updates flow through action-based patterns

**API Layer** (`lib/api/`):
- **Core API**: `lib/api/core.dart` contains main API client (`ApiConnection`)
- **Models**: `lib/api/model/` contains API data types (messages, users, streams, etc.)
- **Routes**: `lib/api/route/` contains API endpoint definitions
- All API types use JSON serialization with generated code (`.g.dart` files)

**Data Layer** (`lib/model/`):
- **Database**: Uses Drift ORM (`database.dart`, `database.g.dart`)
- **Business Logic**: Channel management, autocomplete, content parsing, etc.
- **Bindings**: Platform integrations (`binding.dart`)

**UI Layer** (`lib/widgets/`):
- Material Design components following Figma designs exactly
- **Design System**: Colors and styles in `DesignVariables`, `ContentTheme` classes
- **Key Widgets**: `MessageListView`, compose boxes, action sheets, settings screens

### Key Patterns

**Testing**:
- Use `testWidgets` for UI tests with `TestGlobalStore` for test data
- Use `FakeApiConnection` for mocking API calls
- Use `check()` instead of `expect()` (from `package:checks`)
- All new code requires comprehensive tests

**API Types**:
- Constructors require all parameters (avoid defaults, even `null`)
- Use factory functions in `test/example_data.dart` for test defaults
- Support Zulip Server 7.0+ (use `TODO(server-N)` for newer features)

**Code Generation**:
- API types use `json_serializable` (generates `.g.dart` files)
- Translations use `flutter gen-l10n`
- Database uses Drift code generation
- Icons use custom build system (`tools/icons/`)

## Development Guidelines

### Code Style
- **No auto-formatting**: Don't use `dart format` - follow existing code style
- **Manual formatting**: Match indentation and style of surrounding code
- **Colors/Design**: Use existing `DesignVariables` classes, add new ones for Figma variables

### Dependencies
- Use latest Flutter from `main` channel (`flutter channel main && flutter upgrade`)
- On Mac: Run `tools/upgrade` for dependency updates to sync CocoaPods
- Add new dependencies with explicit version constraints

### Translations
- Add new UI strings to `assets/l10n/app_en.arb`
- Generate translations with `flutter gen-l10n`
- Reference via `AppLocalizations.of(context).stringName`

### Server Compatibility
- Support Zulip Server 7.0+
- Use `TODO(server-N)` comments for newer server features
- Test against current server API

## Testing Strategy

The codebase has extensive test coverage across all layers:

- **Widget Tests**: Use `testWidgets()` with `TestGlobalStore` for UI testing
- **API Tests**: Use `FakeApiConnection` for mocking network requests
- **Unit Tests**: Test business logic, parsers, utilities
- **Integration Tests**: End-to-end flows in `integration_test/`

Always write tests for new features before considering them complete. The testing infrastructure is designed to make this straightforward even for UI and network code.