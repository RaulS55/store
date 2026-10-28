import 'map_date.dart';

const maxCompanyNameLength = 80;
const maxCompanySocialLength = 120;
const maxCompanySocialAccounts = 8;

enum CompanyRubro {
  ropa('Ropa'),
  calzado('Calzado'),
  ambos('Ropa y calzado');

  const CompanyRubro(this.label);
  final String label;

  bool get includesRopa => this != CompanyRubro.calzado;

  bool get includesCalzado => this != CompanyRubro.ropa;

  static CompanyRubro fromStorage(String? value) {
    for (final rubro in CompanyRubro.values) {
      if (rubro.name == value) return rubro;
    }
    return CompanyRubro.ambos;
  }

  static CompanyRubro fromSelection({
    required bool ropa,
    required bool calzado,
  }) {
    if (ropa && calzado) return CompanyRubro.ambos;
    if (calzado) return CompanyRubro.calzado;
    return CompanyRubro.ropa;
  }
}

class Company {
  Company({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
    this.rubro = CompanyRubro.ambos,
    this.phone,
    this.logoUrl,
    List<String> instagram = const [],
    List<String> tiktok = const [],
    List<String> facebook = const [],
  }) : instagram = normalizeSocialAccounts(instagram),
       tiktok = normalizeSocialAccounts(tiktok),
       facebook = normalizeSocialAccounts(facebook);

  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;
  final CompanyRubro rubro;
  final String? phone;
  final String? logoUrl;
  final List<String> instagram;
  final List<String> tiktok;
  final List<String> facebook;

  String get whatsappDigits => (phone ?? '').replaceAll(RegExp(r'\D'), '');

  List<String> get instagramUrls =>
      socialProfileUrls(instagram, host: 'www.instagram.com');

  List<String> get tiktokUrls =>
      socialProfileUrls(tiktok, host: 'www.tiktok.com', atHandle: true);

  List<String> get facebookUrls =>
      socialProfileUrls(facebook, host: 'www.facebook.com');

  factory Company.fromMap(String id, Map<String, dynamic> map) {
    return Company(
      id: id,
      name: (map['name'] as String? ?? '').trim(),
      ownerId: map['ownerId'] as String? ?? '',
      createdAt: parseMapDate(map['createdAt']),
      rubro: CompanyRubro.fromStorage(map['rubro'] as String?),
      phone: blankToNull(map['phone'] as String?),
      logoUrl: blankToNull(map['logoUrl'] as String?),
      instagram: socialAccountsFromStorage(map['instagram']),
      tiktok: socialAccountsFromStorage(map['tiktok']),
      facebook: socialAccountsFromStorage(map['facebook']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'ownerId': ownerId,
      'createdAt': createdAt.toIso8601String(),
      'rubro': rubro.name,
      'phone': phone?.trim(),
      'logoUrl': logoUrl?.trim(),
      'instagram': storedSocialAccounts(instagram),
      'tiktok': storedSocialAccounts(tiktok),
      'facebook': storedSocialAccounts(facebook),
    };
  }

  Company copyWith({
    String? id,
    String? name,
    String? ownerId,
    DateTime? createdAt,
    CompanyRubro? rubro,
    Object? phone = _unset,
    Object? logoUrl = _unset,
    List<String>? instagram,
    List<String>? tiktok,
    List<String>? facebook,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      rubro: rubro ?? this.rubro,
      phone: identical(phone, _unset) ? this.phone : phone as String?,
      logoUrl: identical(logoUrl, _unset) ? this.logoUrl : logoUrl as String?,
      instagram: instagram ?? this.instagram,
      tiktok: tiktok ?? this.tiktok,
      facebook: facebook ?? this.facebook,
    );
  }
}

const _unset = Object();

String? blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

List<String> socialAccountsFromStorage(Object? value) {
  if (value is String) return normalizeSocialAccounts([value]);
  if (value is Iterable) {
    return normalizeSocialAccounts([
      for (final item in value)
        if (item is String) item,
    ]);
  }
  return const [];
}

List<String> normalizeSocialAccounts(Iterable<String> values) {
  final next = <String>[];
  for (final value in values) {
    final trimmed = blankToNull(value);
    if (trimmed == null) continue;
    final duplicate = next.any(
      (item) => item.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) continue;
    next.add(trimmed);
    if (next.length >= maxCompanySocialAccounts) break;
  }
  return List.unmodifiable(next);
}

/// One account stays a string so existing documents keep their shape.
/// Several accounts are stored as a list.
Object? storedSocialAccounts(List<String> values) {
  if (values.isEmpty) return null;
  if (values.length == 1) return values.single;
  return values;
}

List<String> socialProfileUrls(
  List<String> values, {
  required String host,
  bool atHandle = false,
}) {
  final urls = <String>[];
  for (final value in values) {
    final url = socialProfileUrl(value, host: host, atHandle: atHandle);
    if (url != null) urls.add(url);
  }
  return urls;
}

String? socialProfileUrl(
  String? raw, {
  required String host,
  bool atHandle = false,
}) {
  final value = blankToNull(raw);
  if (value == null) return null;
  final parsed = Uri.tryParse(value);
  if (parsed != null &&
      (parsed.scheme == 'http' || parsed.scheme == 'https') &&
      parsed.host.isNotEmpty) {
    return value;
  }
  var handle = value.replaceFirst(RegExp(r'^@+'), '').trim();
  handle = handle.replaceFirst(
    RegExp(
      r'^(www\.)?(instagram\.com|tiktok\.com|facebook\.com|fb\.com)/',
      caseSensitive: false,
    ),
    '',
  );
  handle = handle
      .replaceFirst(RegExp(r'^@+'), '')
      .replaceFirst(RegExp(r'^/+'), '');
  if (handle.isEmpty) return null;
  final path = atHandle ? '@$handle' : handle;
  return 'https://$host/$path';
}
