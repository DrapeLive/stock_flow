import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api/api_client.dart';
import 'core/cache/app_cache.dart';
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
  }

  void _persist(Session session) {
    AppCache.sessionPut('access', session.access);
    AppCache.sessionPut('refresh', session.refresh);
    AppCache.sessionPut('user', session.user.toJson());
  }

  Future<void> logout() async {
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