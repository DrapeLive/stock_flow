import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api/api_client.dart';
import 'core/cache/app_cache.dart';
<<<<<<< HEAD
=======
import 'core/notifications/push_service.dart';
>>>>>>> dev
import 'data/repositories.dart';
import 'features/items/item_sync_service.dart';
import 'models/models.dart';

/// Auth session. Persisted in the `session` Hive box (the JS-cookie
/// equivalent); cleared on logout or 401.
class SessionController extends Notifier<Session?> {
  @override
  Session? build() {
    _restore();
    return _current;
  }

  Session? _current;

  void _restore() {
    try {
      final access = AppCache.sessionGet('access')?.toString();
      final refresh = AppCache.sessionGet('refresh')?.toString();
      final userJson = AppCache.sessionGet('user');
      if (access != null && access.isNotEmpty && userJson != null) {
        _current = Session(
          access: access,
          refresh: refresh ?? '',
          user: AuthUser.fromJson((userJson as Map).cast<String, dynamic>()),
        );
        ApiClient.setToken(access);
        // The login response omits username/email/display_name, so fetch the
        // full profile in the background and keep the persisted session fresh.
        // The Profile page then renders complete details without a visible
        // gap instead of a few seconds after opening it.
        Future.microtask(refreshProfile);
<<<<<<< HEAD
=======
        unawaited(PushService.instance.registerForUser());
>>>>>>> dev
      }
    } catch (_) {
      _current = null;
    }
  }

  Future<void> login(String login, String password) async {
    final session = await repos.auth.login(login, password);
    _current = session;
    _persist(session);
    ApiClient.setToken(session.access);
    state = session;
<<<<<<< HEAD
=======
    unawaited(PushService.instance.registerForUser());
>>>>>>> dev
    unawaited(refreshProfile());
  }

  /// Fetches `/api/auth/profile/` and merges it into the session. The login
  /// response carries no username/email/display_name, so this is the only
  /// source of those fields. Failure (e.g. offline) keeps the session as-is.
  Future<AuthUser?> refreshProfile() async {
    final current = _current ?? state;
    if (current == null) return null;
    try {
      final profile = await repos.auth.profile();
      final updated = Session(
        access: current.access,
        refresh: current.refresh,
        user: profile,
      );
      _current = updated;
      _persist(updated);
      state = updated;
      return profile;
    } catch (_) {
      return null;
    }
  }

  void _persist(Session session) {
    AppCache.sessionPut('access', session.access);
    AppCache.sessionPut('refresh', session.refresh);
    AppCache.sessionPut('user', session.user.toJson());
  }

  Future<void> logout() async {
<<<<<<< HEAD
=======
    await PushService.instance.unregisterForUser();
>>>>>>> dev
    _current = null;
    ApiClient.setToken(null);
    await AppCache.clearAll();
    await AppCache.imageCacheManager.emptyCache();
    AppCache.clearSession();
    AppCache.clearItemSync();
    ItemSyncService.instance.revision.value++;
    state = null;
  }

  Future<void> persistSession() async {
    final s = _current ?? state;
    if (s != null) _persist(s);
  }
}

final sessionProvider = NotifierProvider<SessionController, Session?>(
  SessionController.new,
);

/// Online/offline state driving the offline banner.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final conn = Connectivity();
  bool isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
  yield isOnline(await conn.checkConnectivity());
  yield* conn.onConnectivityChanged.map(isOnline);
});