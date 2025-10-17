import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../widgets/dialog.dart';

/// Handles requesting and checking permissions for calls.
class CallPermissions {
  /// Request camera and microphone permissions for video calls.
  /// Returns true if permissions are granted.
  static Future<bool> requestVideoCallPermissions(BuildContext context) async {
    developer.log('=== Requesting video call permissions ===', name: 'CallPermissions');

    developer.log('Checking current permission statuses...', name: 'CallPermissions');
    final cameraStatus = await Permission.camera.status;
    final microphoneStatus = await Permission.microphone.status;

    developer.log('Camera permission status: $cameraStatus', name: 'CallPermissions');
    developer.log('Microphone permission status: $microphoneStatus', name: 'CallPermissions');

    if (cameraStatus.isGranted && microphoneStatus.isGranted) {
      developer.log('✅ Both permissions already granted', name: 'CallPermissions');
      return true;
    }

    if (cameraStatus.isPermanentlyDenied || microphoneStatus.isPermanentlyDenied) {
      developer.log('❌ Permission permanently denied!', name: 'CallPermissions');
      developer.log('  - Camera: ${cameraStatus.isPermanentlyDenied ? "PERMANENTLY DENIED" : cameraStatus}', name: 'CallPermissions');
      developer.log('  - Microphone: ${microphoneStatus.isPermanentlyDenied ? "PERMANENTLY DENIED" : microphoneStatus}', name: 'CallPermissions');
      if (!context.mounted) return false;
      _showPermissionDeniedDialog(context, isVideo: true);
      return false;
    }

    developer.log('Requesting permissions from user...', name: 'CallPermissions');
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    developer.log('Permission request results:', name: 'CallPermissions');
    for (var entry in statuses.entries) {
      developer.log('  - ${entry.key}: ${entry.value}', name: 'CallPermissions');
    }

    final allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      developer.log('❌ Not all permissions granted!', name: 'CallPermissions');
      if (context.mounted) {
        _showPermissionDeniedDialog(context, isVideo: true);
      }
    } else {
      developer.log('✅ All permissions granted successfully', name: 'CallPermissions');
    }

    return allGranted;
  }

  /// Request microphone permission for audio calls.
  /// Returns true if permission is granted.
  static Future<bool> requestAudioCallPermissions(BuildContext context) async {
    developer.log('=== Requesting audio call permissions ===', name: 'CallPermissions');

    developer.log('Checking current microphone permission status...', name: 'CallPermissions');
    final status = await Permission.microphone.status;
    developer.log('Microphone permission status: $status', name: 'CallPermissions');

    if (status.isGranted) {
      developer.log('✅ Microphone permission already granted', name: 'CallPermissions');
      return true;
    }

    if (status.isPermanentlyDenied) {
      developer.log('❌ Microphone permission permanently denied!', name: 'CallPermissions');
      if (!context.mounted) return false;
      _showPermissionDeniedDialog(context, isVideo: false);
      return false;
    }

    developer.log('Requesting microphone permission from user...', name: 'CallPermissions');
    final result = await Permission.microphone.request();
    developer.log('Microphone permission request result: $result', name: 'CallPermissions');

    if (!result.isGranted) {
      developer.log('❌ Microphone permission denied!', name: 'CallPermissions');
      if (context.mounted) {
        _showPermissionDeniedDialog(context, isVideo: false);
      }
    } else {
      developer.log('✅ Microphone permission granted successfully', name: 'CallPermissions');
    }

    return result.isGranted;
  }

  static void _showPermissionDeniedDialog(
    BuildContext context, {
    required bool isVideo,
  }) {
    showErrorDialog(
      context: context,
      title: 'Permission Required',
      message: isVideo
        ? 'Camera and microphone access are required for video calls. Please grant permissions in your device settings.'
        : 'Microphone access is required for audio calls. Please grant permission in your device settings.',
    );
  }
}


