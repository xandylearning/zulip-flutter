/// Zulip Call Kit - A Flutter plugin for video/audio calling
///
/// This library provides core models and infrastructure for implementing
/// call functionality in Flutter apps.
///
/// The plugin provides:
/// - Core call models (Call, CallSession, CallParticipant, etc.)
/// - Backend adapter pattern for integrating with any backend
/// - Repository and service layer for call management
library;

// Core exports - Models
export 'src/core/models/call.dart';
export 'src/core/models/call_session.dart';
export 'src/core/models/call_participant.dart';
export 'src/core/models/call_event.dart';
export 'src/core/models/call_settings.dart';

// Core exports - Adapters
export 'src/core/adapters/call_backend_adapter.dart';

// Core exports - Repository
export 'src/core/repository/call_repository.dart';

// Core exports - Services
export 'src/core/services/call_kit_service.dart';
