import 'map_date.dart';

const maxCompanyNameLength = 80;
const maxCompanySocialLength = 120;

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
  const Company({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
    this.rubro = CompanyRubro.ambos,
    this.phone,
    this.logoUrl,
    this.instagram,
    this.tiktok,
    this.facebook,
  });

  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;
  final CompanyRubro rubro;
  final String? phone;
  final String? logoUrl;
  final String? instagram;
  final String? tiktok;
  final String? facebook;

  String get whatsappDigits => (phone ?? '').replaceAll(RegExp(r'\D'), '');

  String? get instagramUrl =>
      socialProfileUrl(instagram, host: 'www.instagram.com');

  String? get tiktokUrl =>
      socialProfileUrl(tiktok, host: 'www.tiktok.com', atHandle: true);

  String? get facebookUrl =>
      socialProfileUrl(facebook, host: 'www.facebook.com');

  factory Company.fromMap(String id, Map<String, dynamic> map) {
    return Company(
      id: id,
      name: (map['name'] as String? ?? '').trim(),
      ownerId: map['ownerId'] as String? ?? '',
      createdAt: parseMapDate(map['createdAt']),
      rubro: CompanyRubro.fromStorage(map['rubro'] as String?),
      phone: blankToNull(map['phone'] as String?),
      logoUrl: blankToNull(map['logoUrl'] as String?),
      instagram: blankToNull(map['instagram'] as String?),
      tiktok: blankToNull(map['tiktok'] as String?),
      facebook: blankToNull(map['facebook'] as String?),
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
      'instagram': instagram?.trim(),
      'tiktok': tiktok?.trim(),
      'facebook': facebook?.trim(),
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
    Object? instagram = _unset,
    Object? tiktok = _unset,
    Object? facebook = _unset,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      rubro: rubro ?? this.rubro,
      phone: identical(phone, _unset) ? this.phone : phone as String?,
      logoUrl: identical(logoUrl, _unset) ? this.logoUrl : logoUrl as String?,
      instagram: identical(instagram, _unset)
          ? this.instagram
          : instagram as String?,
      tiktok: identical(tiktok, _unset) ? this.tiktok : tiktok as String?,
      facebook: identical(facebook, _unset)
          ? this.facebook
          : facebook as String?,
    );
  }
}

const _unset = Object();

String? blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
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
