import 'package:zulip_call_kit/zulip_call_kit.dart';

/// Base class for all call-related errors
abstract class CallException implements Exception {
  const CallException(this.message);

  final String message;

  @override
  String toString() => 'CallException: $message';
}

/// Thrown when a call is queued due to busy recipient
class CallQueueedException extends CallException {
  const CallQueueedException({
    required this.queueId,
    required this.expiresAt,
    required this.position,
    String? customMessage,
  }) : super(customMessage ?? 'Call has been queued');

  final String queueId;
  final String expiresAt;
  final String position;

  @override
  String toString() =>
      'CallQueueedException: $message (queueId: $queueId, position: $position, expires: $expiresAt)';
}

/// Thrown when call cooldown is active (race condition prevention)
class CallCooldownException extends CallException {
  const CallCooldownException({
    required this.recipientId,
    required this.remainingSeconds,
  }) : super('Call cooldown active. Wait $remainingSeconds more seconds.');

  final int recipientId;
  final int remainingSeconds;

  @override
  String toString() =>
      'CallCooldownException: Cooldown active for user $recipientId. Wait $remainingSeconds more seconds.';
}

/// Thrown when attempting an invalid state transition
class InvalidCallStateException extends CallException {
  const InvalidCallStateException({
    required this.callId,
    required this.currentState,
    required this.attemptedState,
  }) : super('Invalid state transition from $currentState to $attemptedState');

  final String callId;
  final CallStatus currentState;
  final CallStatus attemptedState;

  @override
  String toString() =>
      'InvalidCallStateException: Cannot transition from $currentState to $attemptedState for call $callId';
}

/// Thrown when a call operation times out
class CallTimeoutException extends CallException {
  const CallTimeoutException({
    required this.callId,
    required this.operation,
  }) : super('Call operation timed out: $operation');

  final String callId;
  final String operation;

  @override
  String toString() =>
      'CallTimeoutException: Operation "$operation" timed out for call $callId';
}

/// Thrown when network failure is detected during a call
class CallNetworkFailureException extends CallException {
  const CallNetworkFailureException({
    required this.callId,
    String? customMessage,
  }) : super(customMessage ?? 'Network failure detected during call');

  final String callId;

  @override
  String toString() =>
      'CallNetworkFailureException: $message (callId: $callId)';
}

/// Thrown when the recipient is not available for a call
class RecipientUnavailableException extends CallException {
  const RecipientUnavailableException({
    required this.recipientId,
    String? reason,
  }) : super(reason ?? 'Recipient is not available');

  final int recipientId;

  @override
  String toString() =>
      'RecipientUnavailableException: $message (recipientId: $recipientId)';
}

/// Thrown when a call is not found
class CallNotFoundException extends CallException {
  const CallNotFoundException({
    required this.callId,
  }) : super('Call not found');

  final String callId;

  @override
  String toString() =>
      'CallNotFoundException: Call with ID $callId not found';
}

/// Thrown when attempting to perform an operation on an already ended call
class CallAlreadyEndedException extends CallException {
  const CallAlreadyEndedException({
    required this.callId,
  }) : super('Call has already ended');

  final String callId;

  @override
  String toString() =>
      'CallAlreadyEndedException: Call $callId has already ended';
}

/// Thrown when server returns an error for a call operation
class CallServerException extends CallException {
  const CallServerException({
    required this.operation,
    required this.statusCode,
    String? serverMessage,
  }) : super(serverMessage ?? 'Server error during call operation');

  final String operation;
  final int statusCode;

  @override
  String toString() =>
      'CallServerException: $message (operation: $operation, statusCode: $statusCode)';
}

/// Thrown when permissions are insufficient for a call operation
class CallPermissionException extends CallException {
  const CallPermissionException({
    required this.operation,
    String? reason,
  }) : super(reason ?? 'Insufficient permissions for call operation');

  final String operation;

  @override
  String toString() =>
      'CallPermissionException: $message (operation: $operation)';
}

/// Result wrapper for call operations that may fail
class CallResult<T> {
  const CallResult.success(this.value) : error = null;
  const CallResult.failure(this.error) : value = null;

  final T? value;
  final CallException? error;

  bool get isSuccess => error == null;
  bool get isFailure => error != null;

  /// Get the value or throw the error
  T get() {
    if (error != null) throw error!;
    return value as T;
  }

  /// Get the value or return null
  T? getOrNull() => value;

  /// Get the value or return a default
  T getOrDefault(T defaultValue) => value ?? defaultValue;

  /// Map the success value to a new type
  CallResult<R> map<R>(R Function(T) mapper) {
    if (isSuccess) {
      return CallResult.success(mapper(value as T));
    }
    return CallResult.failure(error!);
  }

  /// Chain operations that return CallResult
  CallResult<R> flatMap<R>(CallResult<R> Function(T) mapper) {
    if (isSuccess) {
      return mapper(value as T);
    }
    return CallResult.failure(error!);
  }
}
