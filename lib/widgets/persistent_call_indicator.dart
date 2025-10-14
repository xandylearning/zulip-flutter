import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

import '../api/core.dart';
import '../api/model/call.dart';
import '../api/model/events.dart';
import '../api/route/calls.dart';
import '../generated/l10n/zulip_localizations.dart';
import '../model/store.dart';
import 'app.dart';
import '../model/call_ui_state.dart';
import 'call_dialing_screen.dart';
import 'call_wakeup_screen.dart';
import 'jitsi_call_screen.dart';
import 'store.dart';
import 'user.dart';

/// A persistent indicator that shows when there's an active call.
///
/// This widget appears across the entire app when a call is active,
/// allowing users to navigate away from the call screen while the call continues.
/// Similar to WhatsApp's floating call banner.
class PersistentCallIndicator extends StatefulWidget {
  const PersistentCallIndicator({super.key});

  @override
  State<PersistentCallIndicator> createState() => PersistentCallIndicatorState();
}

class PersistentCallIndicatorState extends State<PersistentCallIndicator> {
  final Map<int, StreamSubscription<bool>> _subscriptions = {};
  final Set<int> _changeNotifierAccounts = {};
  bool _hasActiveCall = false;
  bool _globalStoreListenerAdded = false;
  Timer? _timeoutTimer;

  /// Force a check for active calls (useful when call state might have changed)
  void forceCheck() {
    developer.log('PersistentCallIndicator: Force check requested', name: 'PersistentCallIndicator');
    _checkForActiveCalls();
  }

  /// Force end all active calls (emergency cleanup)
  void forceEndAllCalls() {
    developer.log('PersistentCallIndicator: Force ending all calls', name: 'PersistentCallIndicator');
    final globalStore = GlobalStoreWidget.of(context);

    for (final account in globalStore.accounts) {
      final store = globalStore.perAccountSync(account.id);
      if (store != null && store.callStore.hasActiveCall) {
        developer.log('Force ending calls for account ${account.id}', name: 'PersistentCallIndicator');
        store.callStore.endAllActiveCalls();
      }
    }

    // Force a check after ending calls
    _checkForActiveCalls();
  }

  @override
  void initState() {
    super.initState();
    developer.log('PersistentCallIndicator initialized', name: 'PersistentCallIndicator');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Add GlobalStore listener only once
    if (!_globalStoreListenerAdded) {
      final globalStore = GlobalStoreWidget.of(context);
      globalStore.addListener(_onGlobalStoreChange);
      _globalStoreListenerAdded = true;
    }

    _updateSubscriptions();
  }

  void _onGlobalStoreChange() {
    developer.log('GlobalStore changed, updating subscriptions', name: 'PersistentCallIndicator');
    _updateSubscriptions();
  }

  void _updateSubscriptions() {
    final globalStore = GlobalStoreWidget.of(context);

    // Cancel old subscriptions for accounts that no longer exist
    final currentAccountIds = globalStore.accountIds.toSet();
    _subscriptions.keys.toList().forEach((accountId) {
      if (!currentAccountIds.contains(accountId)) {
        developer.log('Removing subscription for account $accountId', name: 'PersistentCallIndicator');
        _subscriptions.remove(accountId)?.cancel();

        // Remove ChangeNotifier listener
        final store = globalStore.perAccountSync(accountId);
        if (store != null && _changeNotifierAccounts.contains(accountId)) {
          store.callStore.removeListener(_checkForActiveCalls);
          _changeNotifierAccounts.remove(accountId);
        }
      }
    });

    // Add subscriptions for new accounts
    for (final account in globalStore.accounts) {
      if (!_subscriptions.containsKey(account.id)) {
        final perAccountStore = globalStore.perAccountSync(account.id);
        if (perAccountStore != null) {
          developer.log('Adding subscription for account ${account.id}', name: 'PersistentCallIndicator');
          final subscription = perAccountStore.callStore.hasActiveCallStream.listen((_) {
            developer.log('Stream event received for account ${account.id}', name: 'PersistentCallIndicator');
            _checkForActiveCalls();
          });
          _subscriptions[account.id] = subscription;

          // Also listen to ChangeNotifier for immediate updates
          if (!_changeNotifierAccounts.contains(account.id)) {
            perAccountStore.callStore.addListener(_checkForActiveCalls);
            _changeNotifierAccounts.add(account.id);
          }
        }
      }
    }

    // Initial check
    _checkForActiveCalls();
  }

  void _checkForActiveCalls() {
    if (!mounted) return;

    final globalStore = GlobalStoreWidget.of(context);
    developer.log('_checkForActiveCalls: Checking ${globalStore.accounts.length} accounts', name: 'PersistentCallIndicator');

    final hasActiveCall = globalStore.accounts.any((account) {
      final store = globalStore.perAccountSync(account.id);
      final hasCall = store?.callStore.hasActiveCall ?? false;
      final activeCall = store?.callStore.activeCall;
      final pendingCalls = store?.callStore.firstPendingCall;

      developer.log('Account ${account.id}: hasCall=$hasCall, activeCall=${activeCall?.callId}, pendingCall=${pendingCalls?.callId}', name: 'PersistentCallIndicator');

      if (hasCall) {
        developer.log('Account ${account.id} has active call', name: 'PersistentCallIndicator');
      }
      return hasCall;
    });

    developer.log('_checkForActiveCalls: hasActiveCall=$hasActiveCall', name: 'PersistentCallIndicator');

    if (_hasActiveCall != hasActiveCall) {
      developer.log('_checkForActiveCalls: State changed from $_hasActiveCall to $hasActiveCall', name: 'PersistentCallIndicator');
      setState(() {
        _hasActiveCall = hasActiveCall;
      });

      // Start timeout timer when call becomes active
      if (hasActiveCall) {
        _startTimeoutTimer();
      } else {
        _stopTimeoutTimer();
      }
    } else {
      // Force a rebuild even if state hasn't changed to ensure UI is updated
      developer.log('_checkForActiveCalls: Forcing rebuild to ensure UI is updated', name: 'PersistentCallIndicator');
      setState(() {});
    }
  }

  void _startTimeoutTimer() {
    _stopTimeoutTimer(); // Cancel any existing timer
    _timeoutTimer = Timer(const Duration(minutes: 5), () {
      developer.log('PersistentCallIndicator: Timeout reached, force ending calls', name: 'PersistentCallIndicator');
      forceEndAllCalls();
    });
  }

  void _stopTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  @override
  void dispose() {
    final globalStore = GlobalStoreWidget.of(context);
    if (_globalStoreListenerAdded) {
      globalStore.removeListener(_onGlobalStoreChange);
    }

    // Remove ChangeNotifier listeners
    for (final accountId in _changeNotifierAccounts) {
      final store = globalStore.perAccountSync(accountId);
      store?.callStore.removeListener(_checkForActiveCalls);
    }
    _changeNotifierAccounts.clear();

    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();

    _stopTimeoutTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    developer.log('PersistentCallIndicator build: _hasActiveCall=$_hasActiveCall', name: 'PersistentCallIndicator');

    if (!_hasActiveCall) {
      developer.log('No active calls, hiding indicator', name: 'PersistentCallIndicator');
      return const SizedBox.shrink();
    }

    // Hide when any call-specific UI is visible (authoritative flag)
    if (CallUiState.isCallUiVisible.value) {
      developer.log('Call UI visible flag is true; hiding indicator', name: 'PersistentCallIndicator');
      return const SizedBox.shrink();
    }

    // Don't show indicator if we're already on a call screen
    if (_isOnCallScreen(context)) {
      developer.log('Currently on a call screen, hiding indicator', name: 'PersistentCallIndicator');
      return const SizedBox.shrink();
    }

    // Find the account with an active call
    final globalStore = GlobalStoreWidget.of(context);
    developer.log('Looking for active call in ${globalStore.accounts.length} accounts', name: 'PersistentCallIndicator');

    for (final account in globalStore.accounts) {
      final perAccountStore = globalStore.perAccountSync(account.id);
      final hasCall = perAccountStore?.callStore.hasActiveCall ?? false;
      developer.log('Account ${account.id}: hasCall=$hasCall', name: 'PersistentCallIndicator');

      if (perAccountStore != null && perAccountStore.callStore.hasActiveCall) {
        final activeCall = perAccountStore.callStore.activeCall;
        final pendingCall = perAccountStore.callStore.firstPendingCall;

        developer.log('Active call found: callId=${activeCall?.callId}, status=${activeCall?.status}', name: 'PersistentCallIndicator');
        developer.log('Pending call found: callId=${pendingCall?.callId}, status=${pendingCall?.status}', name: 'PersistentCallIndicator');

        // Check if there are any calls that are in terminal states (ended, declined, cancelled)
        // If all calls are in terminal states, don't show the indicator
        final allCalls = [activeCall, pendingCall].where((call) => call != null).toList();
        final terminalCalls = allCalls.where((call) =>
          call?.status == CallStatus.ended ||
          call?.status == CallStatus.declined ||
          call?.status == CallStatus.cancelled
        ).toList();

        // If all calls are in terminal states, hide the indicator
        if (allCalls.isNotEmpty && terminalCalls.length == allCalls.length) {
          developer.log('All calls are in terminal states, hiding indicator', name: 'PersistentCallIndicator');
          return const SizedBox.shrink();
        }

        // Check if there are any active calls that are not in terminal states
        final activeCalls = allCalls.where((call) =>
          call?.status != CallStatus.ended &&
          call?.status != CallStatus.declined &&
          call?.status != CallStatus.cancelled
        ).toList();

        // If there are no active calls (all are terminal), hide the indicator
        if (activeCalls.isEmpty) {
          developer.log('No active calls found, hiding indicator', name: 'PersistentCallIndicator');
          return const SizedBox.shrink();
        }

        // Additional check: if the call store says there are no active calls,
        // but we still have calls in the system, they might be stale
        if (!perAccountStore.callStore.hasActiveCall) {
          developer.log('Call store reports no active calls, hiding indicator', name: 'PersistentCallIndicator');
          return const SizedBox.shrink();
        }

        // Force a refresh of the call store to ensure we have the latest state
        // This helps catch cases where the call was ended but the UI hasn't updated
        // Note: We can't call notifyListeners directly, but the call store should
        // automatically notify listeners when the call state changes

        // Additional check: verify the call store state is accurate
        final callStore = perAccountStore.callStore;
        final hasActiveCallFromStore = callStore.hasActiveCall;
        final activeCallFromStore = callStore.activeCall;
        final pendingCallFromStore = callStore.firstPendingCall;

        developer.log('Call store verification: hasActiveCall=$hasActiveCallFromStore, activeCall=${activeCallFromStore?.callId}, pendingCall=${pendingCallFromStore?.callId}', name: 'PersistentCallIndicator');

        // If the call store says there are no active calls, hide the indicator
        if (!hasActiveCallFromStore) {
          developer.log('Call store verification: No active calls found, hiding indicator', name: 'PersistentCallIndicator');
          return const SizedBox.shrink();
        }

        // Additional check: if the active call is in a terminal state, force end it
        if (activeCallFromStore != null) {
          final callStatus = activeCallFromStore.status;
          developer.log('Active call status: $callStatus', name: 'PersistentCallIndicator');

          if (callStatus == CallStatus.ended ||
              callStatus == CallStatus.declined ||
              callStatus == CallStatus.cancelled) {
            developer.log('Active call is in terminal state ($callStatus), forcing call store cleanup', name: 'PersistentCallIndicator');
            // Force the call store to clear the active call
            _forceEndCall(perAccountStore, activeCallFromStore.callId);
            return const SizedBox.shrink();
          }

          // Check if the call has been active for too long (more than 2 hours)
          final callAge = DateTime.now().millisecondsSinceEpoch - (activeCallFromStore.timestamp! * 1000);
          final callAgeMinutes = callAge / (1000 * 60);
          developer.log('Call age: ${callAgeMinutes.toStringAsFixed(1)} minutes', name: 'PersistentCallIndicator');

          if (callAgeMinutes > 120) { // 2 hours
            developer.log('Call has been active for too long (${callAgeMinutes.toStringAsFixed(1)} minutes), force ending', name: 'PersistentCallIndicator');
            _forceEndCall(perAccountStore, activeCallFromStore.callId);
            return const SizedBox.shrink();
          }

          // Check if the call has been in accepted state for too long (more than 30 minutes)
          // This might indicate the Jitsi meeting ended but the call store wasn't updated
          if (callStatus == CallStatus.accepted && callAgeMinutes > 30) {
            developer.log('Call has been in accepted state for too long (${callAgeMinutes.toStringAsFixed(1)} minutes), force ending', name: 'PersistentCallIndicator');
            _forceEndCall(perAccountStore, activeCallFromStore.callId);
            return const SizedBox.shrink();
          }
        }

        developer.log('Showing persistent call indicator for account ${account.id}', name: 'PersistentCallIndicator');
        return PerAccountStoreWidget(
          accountId: account.id,
          child: const _CallIndicatorBanner(),
        );
      }
    }

    developer.log('No account found with active call, hiding indicator', name: 'PersistentCallIndicator');
    return const SizedBox.shrink();
  }

  /// Check if we're currently on a call screen by examining the widget tree
  bool _isOnCallScreen(BuildContext context) {
    try {
      // Prefer checking the route on the root navigator, which reflects
      // the visible page beneath this overlay.
      final rootNav = ZulipApp.navigatorKey.currentState;
      final navCtx = ZulipApp.navigatorKey.currentContext;
      final rootRoute = navCtx != null ? ModalRoute.of(navCtx) : null;
      final rootRouteName = rootRoute?.settings.name ?? '';

      developer.log('Root route name: $rootRouteName, navState: ${rootNav.runtimeType}', name: 'PersistentCallIndicator');

      if (rootRouteName.contains('CallWakeUpScreen') ||
          rootRouteName.contains('JitsiCallScreen') ||
          rootRouteName.contains('CallDialingScreen')) {
        developer.log('Detected call screen via root navigator route name', name: 'PersistentCallIndicator');
        return true;
      }

      // Fallback: Check the current (local) route
      final currentRoute = ModalRoute.of(context);
      final routeName = currentRoute?.settings.name ?? '';
      final routeType = currentRoute.runtimeType.toString();

      developer.log('Local routeName=$routeName, routeType=$routeType', name: 'PersistentCallIndicator');

      if (routeName.contains('CallWakeUpScreen') ||
          routeName.contains('JitsiCallScreen') ||
          routeName.contains('CallDialingScreen') ||
          routeType.contains('CallWakeUpScreen') ||
          routeType.contains('JitsiCallScreen') ||
          routeType.contains('CallDialingScreen')) {
        developer.log('Detected call screen via local route', name: 'PersistentCallIndicator');
        return true;
      }

      // Fallback: Check the navigator stack string for call screens
      final navigator = Navigator.of(context, rootNavigator: true);
      final navigatorState = navigator as NavigatorState?;

      if (navigatorState != null) {
        final routeHistory = navigatorState.toString();
        developer.log('Navigator history: $routeHistory', name: 'PersistentCallIndicator');

        if (routeHistory.contains('CallWakeUpScreen') ||
            routeHistory.contains('JitsiCallScreen') ||
            routeHistory.contains('CallDialingScreen') ||
            routeHistory.contains('CallWakeUp') ||
            routeHistory.contains('JitsiCall') ||
            routeHistory.contains('CallDialing')) {
          developer.log('Found call screen in navigator history', name: 'PersistentCallIndicator');
          return true;
        }
      }

      // Check if any ancestor widget is a call screen
      final callWakeUpScreen = context.findAncestorWidgetOfExactType<CallWakeUpScreen>();
      final jitsiCallScreen = context.findAncestorWidgetOfExactType<JitsiCallScreen>();
      final callDialingScreen = context.findAncestorWidgetOfExactType<CallDialingScreen>();

      if (callWakeUpScreen != null || jitsiCallScreen != null || callDialingScreen != null) {
        developer.log('Found call screen widget in ancestor tree', name: 'PersistentCallIndicator');
        return true;
      }

      return false;
    } catch (e) {
      developer.log('Error checking call screen: $e', name: 'PersistentCallIndicator');
      return false;
    }
  }

  /// Force end a call that's in a terminal state but still showing in the call store
  void _forceEndCall(PerAccountStore store, String callId) {
    try {
      developer.log('Force ending call $callId that is in terminal state', name: 'PersistentCallIndicator');

      // Create a fake CallEndedEvent to force the call store to clear the call
      final callEndedEvent = CallEndedEvent(
        id: 0, // Use 0 as placeholder ID
        callId: callId,
        duration: 0, // Duration is not important for cleanup
      );

      // Handle the event to clear the call from the store
      store.callStore.handleCallEndedEvent(callEndedEvent);

      developer.log('Successfully force ended call $callId', name: 'PersistentCallIndicator');
    } catch (e) {
      developer.log('Failed to force end call $callId: $e', name: 'PersistentCallIndicator');
    }
  }
}

class _CallIndicatorBanner extends StatefulWidget {
  const _CallIndicatorBanner();

  @override
  State<_CallIndicatorBanner> createState() => _CallIndicatorBannerState();
}

class _CallIndicatorBannerState extends State<_CallIndicatorBanner>
    with PerAccountStoreAwareStateMixin<_CallIndicatorBanner>, SingleTickerProviderStateMixin {
  Timer? _durationTimer;
  int _callDuration = 0;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  PerAccountStore? _store;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
    _startDurationTimer();
  }

  @override
  void onNewStore() {
    // Cache store and listen to call store changes to update the UI
    _store = PerAccountStoreWidget.of(context);
    _store!.callStore.addListener(_onCallStoreChange);
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _animationController.dispose();
    _store?.callStore.removeListener(_onCallStoreChange);
    super.dispose();
  }

  void _onCallStoreChange() {
    if (mounted) {
      setState(() {});

      // If no active call, animate out
      if (_store?.callStore.hasActiveCall == false) {
        _animationController.reverse();
      }
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  String _formatDuration() {
    final minutes = _callDuration ~/ 60;
    final seconds = _callDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Handle hang up button tap.
  void _hangUpCall(Call call) {
    developer.log('Hang up button tapped for call ${call.callId}', name: 'PersistentCallIndicator');

    try {
      final store = PerAccountStoreWidget.of(context);
      final accountId = PerAccountStoreWidget.accountIdOf(context);

      // First, try to end the Jitsi meeting by navigating to the Jitsi screen
      // and triggering the end call functionality
      _endJitsiMeeting(call, accountId);

      // Then end the call via API
      _endCall(store.connection, call.callId);

      // Show feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call ended'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      developer.log('Error hanging up call: $e', name: 'PersistentCallIndicator');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end call: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// End the Jitsi meeting directly using the Jitsi SDK.
  void _endJitsiMeeting(Call call, int accountId) {
    try {
      developer.log('Attempting to end Jitsi meeting for call ${call.callId}', name: 'PersistentCallIndicator');

      // Use Jitsi SDK to directly end the meeting
      final jitsiMeetPlugin = JitsiMeet();
      jitsiMeetPlugin.hangUp();

      developer.log('Jitsi meeting ended successfully', name: 'PersistentCallIndicator');
    } catch (e) {
      developer.log('Error ending Jitsi meeting: $e', name: 'PersistentCallIndicator');
      // If direct Jitsi SDK call fails, try the navigation approach as fallback
      _endJitsiMeetingFallback(call, accountId);
    }
  }

  /// Fallback method to end Jitsi meeting by navigating to Jitsi screen.
  void _endJitsiMeetingFallback(Call call, int accountId) {
    try {
      developer.log('Using fallback method to end Jitsi meeting', name: 'PersistentCallIndicator');

      // Navigate to Jitsi screen to trigger the end call functionality
      final navigator = ZulipApp.navigatorKey.currentState;
      if (navigator != null) {
        developer.log('Navigating to Jitsi screen to end meeting', name: 'PersistentCallIndicator');

        // Navigate to Jitsi screen - this will trigger the dispose method
        // which should end the call properly
        navigator.push(
          JitsiCallScreen.buildRoute(
            accountId: accountId,
            call: call,
          ),
        );

        // Immediately pop back to trigger the dispose method
        Future.delayed(const Duration(milliseconds: 100), () {
          if (navigator.canPop()) {
            navigator.pop();
          }
        });
      } else {
        developer.log('Global navigator not available for ending Jitsi meeting', name: 'PersistentCallIndicator');
      }
    } catch (e) {
      developer.log('Error in fallback method: $e', name: 'PersistentCallIndicator');
    }
  }

  /// End a call via API.
  Future<void> _endCall(ApiConnection connection, String callId) async {
    try {
      await endCall(connection, callId: callId);
      developer.log('Call ended successfully via API', name: 'PersistentCallIndicator');
    } catch (e) {
      developer.log('Failed to end call via API: $e', name: 'PersistentCallIndicator');
      rethrow;
    }
  }

  Call? _getActiveCall() {
    final store = PerAccountStoreWidget.of(context);
    final callStore = store.callStore;

    // Check active call first
    if (callStore.activeCall != null) {
      return callStore.activeCall;
    }

    // Check pending outgoing calls
    return callStore.firstPendingCall;
  }

  void _onTap() {
    developer.log('_onTap called', name: 'PersistentCallIndicator');
    final call = _getActiveCall();
    developer.log('Active call: ${call?.callId}, status: ${call?.status}', name: 'PersistentCallIndicator');
    if (call == null) {
      developer.log('No active call, aborting tap', name: 'PersistentCallIndicator');
      return;
    }

    final store = PerAccountStoreWidget.of(context);
    final accountId = PerAccountStoreWidget.accountIdOf(context);

    developer.log('Navigation context: ${context.runtimeType}', name: 'PersistentCallIndicator');

    // Use the global navigator key since we're in a Stack outside the main Navigator
    final navigator = ZulipApp.navigatorKey.currentState;
    if (navigator == null) {
      developer.log('Global navigator not available', name: 'PersistentCallIndicator');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Navigation not available'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    developer.log('Using global navigator', name: 'PersistentCallIndicator');
    _navigateWithNavigatorState(navigator, call, accountId, store);
  }

  void _navigateWithNavigatorState(NavigatorState navigator, Call call, int accountId, PerAccountStore store) {
    try {
      // Determine if the current user is the caller (initiator) or recipient
      final isCaller = call.callerId == store.selfUserId;
      developer.log('Navigation decision: isCaller=$isCaller, callerId=${call.callerId}, selfUserId=${store.selfUserId}', name: 'PersistentCallIndicator');
      developer.log('Call details: callId=${call.callId}, status=${call.status}, jitsiUrl=${call.jitsiUrl}', name: 'PersistentCallIndicator');

      // Check if the call is already active or in progress
      if (call.status == CallStatus.accepted || call.status == CallStatus.ringing) {
        // Call is active or ringing - navigate directly to Jitsi screen
        developer.log('Call is active/ringing (${call.status}), navigating to JitsiCallScreen for call ${call.callId}', name: 'PersistentCallIndicator');

        navigator.push(
          JitsiCallScreen.buildRoute(
            accountId: accountId,
            call: call,
          ),
        );
        developer.log('Navigation to JitsiCallScreen completed', name: 'PersistentCallIndicator');
        return;
      }

      if (isCaller) {
        // User is the call initiator - navigate to dialing screen
        developer.log('Navigating to CallDialingScreen for call ${call.callId}', name: 'PersistentCallIndicator');

        // Get the recipient user information
        final recipient = store.getUser(call.recipientId);
        if (recipient == null) {
          developer.log('Could not find recipient user ${call.recipientId}', name: 'PersistentCallIndicator');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not find recipient information'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        navigator.push(
          CallDialingScreen.buildRoute(
            accountId: accountId,
            call: call,
            recipient: recipient,
          ),
        );
        developer.log('Navigation to CallDialingScreen completed', name: 'PersistentCallIndicator');
      } else {
        // User is the call recipient - navigate to wakeup screen
        developer.log('Navigating to CallWakeUpScreen for call ${call.callId}', name: 'PersistentCallIndicator');

        navigator.push(
          CallWakeUpScreen.buildRoute(
            accountId: accountId,
            call: call,
          ),
        );
        developer.log('Navigation to CallWakeUpScreen completed', name: 'PersistentCallIndicator');
      }
    } catch (e, stackTrace) {
      developer.log('Navigation failed: $e', name: 'PersistentCallIndicator');
      developer.log('Stack trace: $stackTrace', name: 'PersistentCallIndicator');

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open call: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final call = _getActiveCall();
    developer.log('_CallIndicatorBanner build: call=${call?.callId}, status=${call?.status}', name: 'PersistentCallIndicator');

    if (call == null) {
      developer.log('No active call found in banner', name: 'PersistentCallIndicator');
      return const SizedBox.shrink();
    }

    developer.log('Building banner for call ${call.callId}, status: ${call.status}', name: 'PersistentCallIndicator');

    final store = PerAccountStoreWidget.of(context);
    final l10n = ZulipLocalizations.of(context);

    // Determine the other user (not self)
    final otherUserId = call.callerId == store.selfUserId
        ? call.recipientId
        : call.callerId;
    final otherUser = store.getUser(otherUserId);

    if (otherUser == null) {
      developer.log('Could not find other user $otherUserId', name: 'PersistentCallIndicator');
      return const SizedBox.shrink();
    }

    // Determine status text and background color
    final String statusText;
    final Color backgroundColor;

    switch (call.status) {
      case CallStatus.created:
      case CallStatus.ringing:
        // Show a generic ringing label without call type
        statusText = l10n.callStatusRinging;
        backgroundColor = const Color(0xFF0066FF); // Blue for ringing
      case CallStatus.accepted:
        final callTypeStr = call.callType == CallType.video
            ? l10n.callIndicatorOngoingVideo
            : l10n.callIndicatorOngoingAudio;
        statusText = '$callTypeStr • ${_formatDuration()}';
        backgroundColor = const Color(0xFF25D366); // Green for ongoing
      default:
        developer.log('Call status ${call.status} not shown in banner', name: 'PersistentCallIndicator');
        return const SizedBox.shrink();
    }

    developer.log('Showing banner: $statusText', name: 'PersistentCallIndicator');

    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        type: MaterialType.canvas,
        color: backgroundColor,
        elevation: 4,
        child: SafeArea(
          bottom: false,
          child: InkWell(
            onTap: _onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Avatar
                  Avatar(
                    userId: otherUser.userId,
                    size: 32,
                    borderRadius: 16,
                  ),

                  const SizedBox(width: 12),

                  // Call info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          otherUser.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Show hang button if call is active (accepted status)
                  if (call.status == CallStatus.accepted) ...[
                    // Hang button
                    GestureDetector(
                      onTap: () => _hangUpCall(call),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ] else ...[
                    // Tap to return hint for ringing calls
                    const Icon(
                      Icons.keyboard_arrow_up,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

