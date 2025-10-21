import 'dart:async';
import 'dart:developer' as developer;

import '../api/core.dart';
import '../api/route/calls.dart' as api;
import 'call_errors.dart';

/// Network resilience manager for call operations
///
/// Provides retry logic, timeout handling, and error recovery for call API operations.
class CallNetworkManager {
  CallNetworkManager({
    required this.connection,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.operationTimeout = const Duration(seconds: 30),
  });

  final ApiConnection connection;
  final int maxRetries;
  final Duration retryDelay;
  final Duration operationTimeout;

  /// Execute an API call with retry logic
  Future<T> executeWithRetry<T>({
    required String operationName,
    required Future<T> Function() operation,
    bool Function(Object)? shouldRetry,
  }) async {
    int attempts = 0;
    Object? lastError;

    while (attempts < maxRetries) {
      try {
        attempts++;
        developer.log(
          'CallNetworkManager: Executing $operationName (attempt $attempts/$maxRetries)',
          name: 'CallNetworkManager',
        );

        final result = await operation().timeout(
          operationTimeout,
          onTimeout: () {
            throw CallTimeoutException(
              callId: 'unknown',
              operation: operationName,
            );
          },
        );

        developer.log(
          'CallNetworkManager: $operationName succeeded on attempt $attempts',
          name: 'CallNetworkManager',
        );

        return result;
      } catch (e) {
        lastError = e;

        developer.log(
          'CallNetworkManager: $operationName failed on attempt $attempts: $e',
          name: 'CallNetworkManager',
        );

        // Check if we should retry
        if (attempts >= maxRetries) {
          developer.log(
            'CallNetworkManager: Max retries reached for $operationName',
            name: 'CallNetworkManager',
          );
          break;
        }

        // Check custom retry condition
        if (shouldRetry != null && !shouldRetry(e)) {
          developer.log(
            'CallNetworkManager: Should not retry $operationName',
            name: 'CallNetworkManager',
          );
          break;
        }

        // Default: don't retry on client errors (4xx) or specific call errors
        if (_shouldNotRetry(e)) {
          developer.log(
            'CallNetworkManager: Non-retryable error for $operationName',
            name: 'CallNetworkManager',
          );
          break;
        }

        // Wait before retrying (exponential backoff)
        final delay = retryDelay * attempts;
        developer.log(
          'CallNetworkManager: Retrying $operationName in ${delay.inSeconds}s',
          name: 'CallNetworkManager',
        );
        await Future<void>.delayed(delay);
      }
    }

    // All retries exhausted
    throw CallServerException(
      operation: operationName,
      statusCode: 0,
      serverMessage: 'Operation failed after $attempts attempts: $lastError',
    );
  }

  /// Check if an error should not be retried
  bool _shouldNotRetry(Object error) {
    // Don't retry client errors or specific call exceptions
    if (error is CallCooldownException) return true;
    if (error is InvalidCallStateException) return true;
    if (error is CallAlreadyEndedException) return true;
    if (error is CallPermissionException) return true;
    if (error is CallNotFoundException) return true;

    // Check for HTTP 4xx errors (client errors)
    final errorString = error.toString();
    if (errorString.contains('400') ||
        errorString.contains('401') ||
        errorString.contains('403') ||
        errorString.contains('404')) {
      return true;
    }

    return false;
  }

  /// Create a call with retry logic
  Future<CallResult<T>> createCallSafe<T>({
    required int userId,
    required bool isVideoCall,
    required T Function(dynamic) responseMapper,
  }) async {
    try {
      final response = await executeWithRetry(
        operationName: 'createCall',
        operation: () => api.createCall(
          connection,
          userId: userId,
          isVideoCall: isVideoCall,
        ),
      );
      return CallResult.success(responseMapper(response));
    } on CallException catch (e) {
      return CallResult.failure(e);
    } catch (e) {
      return CallResult.failure(
        CallServerException(
          operation: 'createCall',
          statusCode: 0,
          serverMessage: e.toString(),
        ),
      );
    }
  }

  /// Acknowledge a call with retry logic
  Future<CallResult<void>> acknowledgeCallSafe(String callId) async {
    try {
      await executeWithRetry(
        operationName: 'acknowledgeCall',
        operation: () => api.acknowledgeCall(connection, callId: callId),
      );
      return const CallResult.success(null);
    } on CallException catch (e) {
      return CallResult.failure(e);
    } catch (e) {
      return CallResult.failure(
        CallServerException(
          operation: 'acknowledgeCall',
          statusCode: 0,
          serverMessage: e.toString(),
        ),
      );
    }
  }

  /// Accept a call with retry logic
  Future<CallResult<void>> acceptCallSafe(String callId) async {
    try {
      await executeWithRetry(
        operationName: 'acceptCall',
        operation: () => api.acceptCall(connection, callId: callId),
      );
      return const CallResult.success(null);
    } on CallException catch (e) {
      return CallResult.failure(e);
    } catch (e) {
      return CallResult.failure(
        CallServerException(
          operation: 'acceptCall',
          statusCode: 0,
          serverMessage: e.toString(),
        ),
      );
    }
  }

  /// Decline a call with retry logic
  Future<CallResult<void>> declineCallSafe(String callId) async {
    try {
      await executeWithRetry(
        operationName: 'declineCall',
        operation: () => api.declineCall(connection, callId: callId),
      );
      return const CallResult.success(null);
    } on CallException catch (e) {
      return CallResult.failure(e);
    } catch (e) {
      return CallResult.failure(
        CallServerException(
          operation: 'declineCall',
          statusCode: 0,
          serverMessage: e.toString(),
        ),
      );
    }
  }

  /// End a call with retry logic
  Future<CallResult<void>> endCallSafe(String callId, {int? duration}) async {
    try {
      await executeWithRetry(
        operationName: 'endCall',
        operation: () => api.endCall(
          connection,
          callId: callId,
          duration: duration,
        ),
      );
      return const CallResult.success(null);
    } on CallException catch (e) {
      return CallResult.failure(e);
    } catch (e) {
      return CallResult.failure(
        CallServerException(
          operation: 'endCall',
          statusCode: 0,
          serverMessage: e.toString(),
        ),
      );
    }
  }

  /// Cancel a call with retry logic
  Future<CallResult<void>> cancelCallSafe(String callId) async {
    try {
      await executeWithRetry(
        operationName: 'cancelCall',
        operation: () => api.cancelCall(connection, callId: callId),
      );
      return const CallResult.success(null);
    } on CallException catch (e) {
      return CallResult.failure(e);
    } catch (e) {
      return CallResult.failure(
        CallServerException(
          operation: 'cancelCall',
          statusCode: 0,
          serverMessage: e.toString(),
        ),
      );
    }
  }

  /// Send heartbeat with retry logic
  Future<CallResult<void>> sendHeartbeatSafe(
    String callId, {
    bool isBackgrounded = false,
  }) async {
    try {
      await executeWithRetry(
        operationName: 'sendHeartbeat',
        operation: () => api.sendHeartbeat(
          connection,
          callId: callId,
          isBackgrounded: isBackgrounded,
        ),
        // Don't retry heartbeats aggressively - next one will come soon
        shouldRetry: (error) => false,
      );
      return const CallResult.success(null);
    } on CallException catch (e) {
      return CallResult.failure(e);
    } catch (e) {
      // Heartbeat failures are not critical
      developer.log(
        'CallNetworkManager: Heartbeat failed (non-critical): $e',
        name: 'CallNetworkManager',
      );
      return const CallResult.success(null);
    }
  }
}

/// Heartbeat manager for active calls
///
/// Sends periodic heartbeats to detect network failures.
class CallHeartbeatManager {
  CallHeartbeatManager({
    required this.networkManager,
    this.heartbeatInterval = const Duration(seconds: 30),
  });

  final CallNetworkManager networkManager;
  final Duration heartbeatInterval;

  final Map<String, Timer> _activeHeartbeats = {};
  final Map<String, int> _failureCount = {};

  /// Maximum consecutive failures before considering network disconnected
  static const int maxConsecutiveFailures = 2;

  /// Start sending heartbeats for a call
  void startHeartbeat(String callId, {required void Function() onNetworkFailure}) {
    stopHeartbeat(callId);

    developer.log(
      'CallHeartbeatManager: Starting heartbeat for call $callId',
      name: 'CallHeartbeatManager',
    );

    _failureCount[callId] = 0;

    _activeHeartbeats[callId] = Timer.periodic(heartbeatInterval, (timer) async {
      developer.log(
        'CallHeartbeatManager: Sending heartbeat for call $callId',
        name: 'CallHeartbeatManager',
      );

      final result = await networkManager.sendHeartbeatSafe(callId);

      if (result.isFailure) {
        _failureCount[callId] = (_failureCount[callId] ?? 0) + 1;
        developer.log(
          'CallHeartbeatManager: Heartbeat failed for call $callId '
          '(${_failureCount[callId]}/$maxConsecutiveFailures)',
          name: 'CallHeartbeatManager',
        );

        if ((_failureCount[callId] ?? 0) >= maxConsecutiveFailures) {
          developer.log(
            'CallHeartbeatManager: Network failure detected for call $callId',
            name: 'CallHeartbeatManager',
          );
          stopHeartbeat(callId);
          onNetworkFailure();
        }
      } else {
        _failureCount[callId] = 0;
      }
    });
  }

  /// Stop sending heartbeats for a call
  void stopHeartbeat(String callId) {
    _activeHeartbeats[callId]?.cancel();
    _activeHeartbeats.remove(callId);
    _failureCount.remove(callId);

    developer.log(
      'CallHeartbeatManager: Stopped heartbeat for call $callId',
      name: 'CallHeartbeatManager',
    );
  }

  /// Stop all heartbeats
  void stopAll() {
    for (final callId in _activeHeartbeats.keys.toList()) {
      stopHeartbeat(callId);
    }
  }

  void dispose() {
    stopAll();
  }
}
