import 'package:flutter/foundation.dart';

/// Global UI state to indicate a call-specific full-screen UI is visible.
///
/// When true, components like the persistent call indicator should hide.
class CallUiState {
  CallUiState._();

  /// Whether any call screen (wakeup/dialing/jitsi) is currently visible.
  static final ValueNotifier<bool> isCallUiVisible = ValueNotifier<bool>(false);
}


