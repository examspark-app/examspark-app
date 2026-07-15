import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart'
    hide SupabaseClient;
import 'package:examspark_frontend/core/network/supabase_client.dart';

// #region agent log
void _agentLog(String hypothesisId, String location, String message, Map<String, Object?> data) {
  http
      .post(
        Uri.parse('http://127.0.0.1:7873/ingest/2b81c552-406d-48cd-a23e-89c0b6b9e62a'),
        headers: {
          'Content-Type': 'application/json',
          'X-Debug-Session-Id': '945329',
        },
        body: jsonEncode({
          'sessionId': '945329',
          'runId': 'pre-fix',
          'hypothesisId': hypothesisId,
          'location': location,
          'message': message,
          'data': data,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      )
      .catchError((_) => http.Response('', 500));
}
// #endregion

/// Keeps credits, plan tier, and group-membership revision live for the
/// signed-in user — Supabase Realtime + resume/tab refetch.
///
/// Start from [AppShell] after login; [stop] on logout / session clear.
/// Founder must enable Realtime on `users`, `user_subscriptions`,
/// `class_memberships` (see FOUNDER_SESSION_LIVE_SYNC.md).
class SessionLiveSync extends ChangeNotifier with WidgetsBindingObserver {
  SessionLiveSync._();
  static final SessionLiveSync instance = SessionLiveSync._();

  String? _userId;
  RealtimeChannel? _channel;
  bool _observerAttached = false;

  int creditsBalance = 0;
  String planId = 'free';
  /// Bumped when the user's class_memberships rows change.
  int membershipsVersion = 0;

  bool get isRunning => _userId != null && _channel != null;

  Future<void> start(String userId) async {
    // #region agent log
    _agentLog('A', 'session_live_sync.dart:start', 'start called', {
      'userIdSuffix': userId.length > 8 ? userId.substring(userId.length - 8) : userId,
      'initialized': SupabaseClient.instance.isInitialized,
      'alreadyRunning': _userId == userId && _channel != null,
    });
    // #endregion
    if (!SupabaseClient.instance.isInitialized) return;
    if (_userId == userId && _channel != null) {
      await refreshAll();
      return;
    }
    await stop();
    _userId = userId;
    if (!_observerAttached) {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
    }
    await refreshAll();
    _subscribe(userId);
  }

  Future<void> stop() async {
    if (_observerAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _observerAttached = false;
    }
    final ch = _channel;
    _channel = null;
    _userId = null;
    if (ch != null) {
      try {
        await SupabaseClient.instance.client.removeChannel(ch);
      } catch (_) {}
    }
  }

  /// Full pull — used on start, resume, and when Realtime is unavailable.
  Future<void> refreshAll() async {
    final userId = _userId ?? SupabaseClient.instance.currentUser?.id;
    if (userId == null || !SupabaseClient.instance.isInitialized) return;

    try {
      final profile = await SupabaseClient.instance.getUserProfile(userId);
      var plan = 'free';
      Object? planErr;
      try {
        plan = await SupabaseClient.instance.getPlanTier(userId);
      } catch (e) {
        planErr = e.toString();
      }

      creditsBalance = profile?['credits_balance'] as int? ?? 0;
      planId = plan;
      // #region agent log
      _agentLog('B', 'session_live_sync.dart:refreshAll', 'refresh result', {
        'userIdSuffix': userId.length > 8 ? userId.substring(userId.length - 8) : userId,
        'credits': creditsBalance,
        'planId': planId,
        'planErr': planErr?.toString(),
        'profileNull': profile == null,
      });
      // #endregion
      notifyListeners();
    } catch (e) {
      // #region agent log
      _agentLog('E', 'session_live_sync.dart:refreshAll', 'refresh threw', {
        'error': e.toString(),
      });
      // #endregion
    }
  }

  void _subscribe(String userId) {
    final client = SupabaseClient.instance.client;
    final channel = client.channel('session-live-$userId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final bal = payload.newRecord['credits_balance'];
            // #region agent log
            _agentLog('C', 'session_live_sync.dart:usersRealtime', 'users UPDATE event', {
              'creditsRaw': bal?.toString(),
            });
            // #endregion
            if (bal is int) {
              creditsBalance = bal;
              notifyListeners();
            } else if (bal is num) {
              creditsBalance = bal.toInt();
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_subscriptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) {
            // #region agent log
            _agentLog('C', 'session_live_sync.dart:subsRealtime', 'user_subscriptions event', {});
            // #endregion
            unawaited(_refreshPlan(userId));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'class_memberships',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: userId,
          ),
          callback: (_) {
            // #region agent log
            _agentLog('C', 'session_live_sync.dart:membershipsRealtime', 'class_memberships event', {});
            // #endregion
            membershipsVersion++;
            notifyListeners();
          },
        )
        .subscribe((status, [err]) {
          // #region agent log
          _agentLog('C', 'session_live_sync.dart:subscribe', 'channel status', {
            'status': status.name,
            'err': err?.toString(),
          });
          // #endregion
        });

    _channel = channel;
  }

  Future<void> _refreshPlan(String userId) async {
    try {
      planId = await SupabaseClient.instance.getPlanTier(userId);
      // #region agent log
      _agentLog('B', 'session_live_sync.dart:_refreshPlan', 'plan after realtime', {
        'planId': planId,
      });
      // #endregion
      notifyListeners();
    } catch (e) {
      // #region agent log
      _agentLog('E', 'session_live_sync.dart:_refreshPlan', 'plan refresh threw', {
        'error': e.toString(),
      });
      // #endregion
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _userId != null) {
      unawaited(refreshAll());
    }
  }
}
