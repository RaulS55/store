import '../models/app_user.dart';
import '../models/company.dart';
import '../models/membership.dart';
import 'local/hive_catalog_cache.dart';

class SessionSnapshot {
  const SessionSnapshot({
    required this.user,
    required this.company,
    required this.membership,
  });

  final AppUser user;
  final Company company;
  final Membership membership;
}

abstract class SessionCache {
  SessionSnapshot? read(String uid);

  Future<void> write(SessionSnapshot snapshot);

  Future<void> clear(String uid);
}

class MemorySessionCache implements SessionCache {
  final _data = <String, SessionSnapshot>{};

  @override
  SessionSnapshot? read(String uid) => _data[uid];

  @override
  Future<void> write(SessionSnapshot snapshot) async {
    _data[snapshot.user.id] = snapshot;
  }

  @override
  Future<void> clear(String uid) async {
    _data.remove(uid);
  }
}

class HiveSessionCache implements SessionCache {
  HiveSessionCache(this._cache);

  final HiveCatalogCache _cache;

  static String keyFor(String uid) => 'session|$uid';

  @override
  SessionSnapshot? read(String uid) {
    final map = _cache.readMetaMap(keyFor(uid));
    if (map == null) return null;
    try {
      final userMap = _asMap(map['user']);
      final companyMap = _asMap(map['company']);
      final membershipMap = _asMap(map['membership']);
      if (userMap == null || companyMap == null || membershipMap == null) {
        return null;
      }
      final userId = (userMap['id'] as String?)?.trim() ?? uid;
      final companyId = (companyMap['id'] as String?)?.trim() ?? '';
      final memberUid = (membershipMap['uid'] as String?)?.trim() ?? userId;
      if (userId.isEmpty || companyId.isEmpty) return null;
      return SessionSnapshot(
        user: AppUser.fromMap(userId, userMap),
        company: Company.fromMap(companyId, companyMap),
        membership: Membership.fromMap(memberUid, companyId, membershipMap),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(SessionSnapshot snapshot) async {
    await _cache.saveCompany(snapshot.company);
    await _cache.writeMetaMap(keyFor(snapshot.user.id), {
      'user': {'id': snapshot.user.id, ...snapshot.user.toMap()},
      'company': {'id': snapshot.company.id, ...snapshot.company.toMap()},
      'membership': {
        'uid': snapshot.membership.uid,
        'companyId': snapshot.membership.companyId,
        ...snapshot.membership.toMap(),
      },
    });
  }

  @override
  Future<void> clear(String uid) {
    return _cache.deleteMetaKey(keyFor(uid));
  }

  Map<String, dynamic>? _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return {for (final entry in raw.entries) '${entry.key}': entry.value};
    }
    return null;
  }
}
