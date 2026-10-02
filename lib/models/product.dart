import 'package:flutter/material.dart';

import 'map_value.dart';
import 'sync_record.dart';

enum ApparelLine { ropa, calzado }

class ApparelCategory {
  const ApparelCategory._(this.name, this.label, this.line);

  factory ApparelCategory.custom(String label) {
    final trimmed = label.trim();
    return ApparelCategory._(trimmed, trimmed, ApparelLine.ropa);
  }

  final String name;
  final String label;
  final ApparelLine line;

  bool get isCustom => !values.contains(this);

  static const remeras = ApparelCategory._(
    'remeras',
    'Remeras',
    ApparelLine.ropa,
  );
  static const musculosas = ApparelCategory._(
    'musculosas',
    'Musculosas',
    ApparelLine.ropa,
  );
  static const poleras = ApparelCategory._(
    'poleras',
    'Poleras',
    ApparelLine.ropa,
  );
  static const camisas = ApparelCategory._(
    'camisas',
    'Camisas',
    ApparelLine.ropa,
  );
  static const chombas = ApparelCategory._(
    'chombas',
    'Chombas',
    ApparelLine.ropa,
  );
  static const tops = ApparelCategory._('tops', 'Tops', ApparelLine.ropa);
  static const bodies = ApparelCategory._('bodies', 'Bodies', ApparelLine.ropa);
  static const buzos = ApparelCategory._('buzos', 'Buzos', ApparelLine.ropa);
  static const sweaters = ApparelCategory._(
    'sweaters',
    'Sweaters',
    ApparelLine.ropa,
  );
  static const cardigans = ApparelCategory._(
    'cardigans',
    'Cardigans',
    ApparelLine.ropa,
  );
  static const camperas = ApparelCategory._(
    'camperas',
    'Camperas',
    ApparelLine.ropa,
  );
  static const abrigos = ApparelCategory._(
    'abrigos',
    'Abrigos',
    ApparelLine.ropa,
  );
  static const blazers = ApparelCategory._(
    'blazers',
    'Blazers',
    ApparelLine.ropa,
  );
  static const chalecos = ApparelCategory._(
    'chalecos',
    'Chalecos',
    ApparelLine.ropa,
  );
  static const pantalones = ApparelCategory._(
    'pantalones',
    'Pantalones',
    ApparelLine.ropa,
  );
  static const jeans = ApparelCategory._('jeans', 'Jeans', ApparelLine.ropa);
  static const shorts = ApparelCategory._('shorts', 'Shorts', ApparelLine.ropa);
  static const faldas = ApparelCategory._('faldas', 'Faldas', ApparelLine.ropa);
  static const vestidos = ApparelCategory._(
    'vestidos',
    'Vestidos',
    ApparelLine.ropa,
  );
  static const enteritos = ApparelCategory._(
    'enteritos',
    'Enteritos',
    ApparelLine.ropa,
  );
  static const conjuntos = ApparelCategory._(
    'conjuntos',
    'Conjuntos',
    ApparelLine.ropa,
  );
  static const pijamas = ApparelCategory._(
    'pijamas',
    'Pijamas',
    ApparelLine.ropa,
  );
  static const ropaInterior = ApparelCategory._(
    'ropaInterior',
    'Ropa interior',
    ApparelLine.ropa,
  );
  static const trajesDeBano = ApparelCategory._(
    'trajesDeBano',
    'Trajes de baño',
    ApparelLine.ropa,
  );
  static const medias = ApparelCategory._('medias', 'Medias', ApparelLine.ropa);
  static const gorras = ApparelCategory._('gorras', 'Gorras', ApparelLine.ropa);
  static const bufandas = ApparelCategory._(
    'bufandas',
    'Bufandas',
    ApparelLine.ropa,
  );
  static const accesorios = ApparelCategory._(
    'accesorios',
    'Accesorios',
    ApparelLine.ropa,
  );
  static const zapatillas = ApparelCategory._(
    'zapatillas',
    'Zapatillas',
    ApparelLine.calzado,
  );
  static const zapatos = ApparelCategory._(
    'zapatos',
    'Zapatos',
    ApparelLine.calzado,
  );
  static const botas = ApparelCategory._('botas', 'Botas', ApparelLine.calzado);
  static const botinetas = ApparelCategory._(
    'botinetas',
    'Botinetas',
    ApparelLine.calzado,
  );
  static const borcegos = ApparelCategory._(
    'borcegos',
    'Borcegos',
    ApparelLine.calzado,
  );
  static const sandalias = ApparelCategory._(
    'sandalias',
    'Sandalias',
    ApparelLine.calzado,
  );
  static const chatitas = ApparelCategory._(
    'chatitas',
    'Chatitas',
    ApparelLine.calzado,
  );
  static const mocasines = ApparelCategory._(
    'mocasines',
    'Mocasines',
    ApparelLine.calzado,
  );
  static const zuecos = ApparelCategory._(
    'zuecos',
    'Zuecos',
    ApparelLine.calzado,
  );
  static const alpargatas = ApparelCategory._(
    'alpargatas',
    'Alpargatas',
    ApparelLine.calzado,
  );
  static const ojotas = ApparelCategory._(
    'ojotas',
    'Ojotas',
    ApparelLine.calzado,
  );
  static const pantuflas = ApparelCategory._(
    'pantuflas',
    'Pantuflas',
    ApparelLine.calzado,
  );
  static const tacos = ApparelCategory._('tacos', 'Tacos', ApparelLine.calzado);
  static const botasDeLluvia = ApparelCategory._(
    'botasDeLluvia',
    'Botas de lluvia',
    ApparelLine.calzado,
  );
  static const calzado = ApparelCategory._(
    'calzado',
    'Calzado',
    ApparelLine.calzado,
  );

  static const values = [
    remeras,
    musculosas,
    poleras,
    camisas,
    chombas,
    tops,
    bodies,
    buzos,
    sweaters,
    cardigans,
    camperas,
    abrigos,
    blazers,
    chalecos,
    pantalones,
    jeans,
    shorts,
    faldas,
    vestidos,
    enteritos,
    conjuntos,
    pijamas,
    ropaInterior,
    trajesDeBano,
    medias,
    gorras,
    bufandas,
    accesorios,
    zapatillas,
    zapatos,
    botas,
    botinetas,
    borcegos,
    sandalias,
    chatitas,
    mocasines,
    zuecos,
    alpargatas,
    ojotas,
    pantuflas,
    tacos,
    botasDeLluvia,
    calzado,
  ];

  static ApparelCategory fromStorage(String value) {
    final known = tryFromStorage(value) ?? match(value);
    if (known != null) return known;
    final raw = value.trim();
    if (raw.isEmpty) {
      throw FormatException('Unknown category: $value');
    }
    return ApparelCategory.custom(raw);
  }

  static ApparelCategory? tryFromStorage(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    for (final category in values) {
      if (category.name == raw) return category;
    }
    return null;
  }

  static ApparelCategory? match(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return null;
    for (final category in values) {
      if (category.label.toLowerCase() == query) return category;
      if (category.name.toLowerCase() == query) return category;
    }
    return null;
  }

  static ApparelCategory? resolve(String value) {
    final query = value.trim();
    if (query.isEmpty) return null;
    return match(query) ?? ApparelCategory.custom(query);
  }

  static List<ApparelCategory> forLine(ApparelLine line) {
    return [
      for (final category in values)
        if (category.line == line) category,
    ];
  }

  static List<ApparelCategory> mergeVisible({
    required List<ApparelCategory> predefined,
    required Iterable<ApparelCategory> used,
  }) {
    final counts = <ApparelCategory, int>{};
    for (final category in used) {
      counts[category] = (counts[category] ?? 0) + 1;
    }
    final allowed = predefined.toSet();
    final list = [
      for (final category in counts.keys)
        if (allowed.contains(category) || category.isCustom) category,
    ];
    list.sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      if (byCount != 0) return byCount;
      if (a.isCustom != b.isCustom) return a.isCustom ? 1 : -1;
      final aIndex = predefined.indexOf(a);
      final bIndex = predefined.indexOf(b);
      if (aIndex >= 0 && bIndex >= 0) return aIndex.compareTo(bIndex);
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return list;
  }

  static List<ApparelCategory> mergeChoices({
    required List<ApparelCategory> predefined,
    required Iterable<ApparelCategory> used,
  }) {
    final seen = {...predefined};
    final extras = <ApparelCategory>[];
    for (final category in used) {
      if (category.isCustom && seen.add(category)) extras.add(category);
    }
    extras.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return [...predefined, ...extras];
  }

  ApparelCategory get chipFamily => this;

  @override
  bool operator ==(Object other) =>
      other is ApparelCategory &&
      other.name.toLowerCase() == name.toLowerCase();

  @override
  int get hashCode => name.toLowerCase().hashCode;
}

enum ApparelAudience {
  hombre('Hombre'),
  mujer('Mujer'),
  infantil('Infantil'),
  bebe('Bebé'),
  juvenil('Juvenil'),
  unisex('Unisex');

  const ApparelAudience(this.label);
  final String label;

  static ApparelAudience fromStorage(String value) {
    final audience = tryFromStorage(value);
    if (audience == null) {
      throw FormatException('Unknown audience: $value');
    }
    return audience;
  }

  static ApparelAudience? tryFromStorage(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    for (final audience in values) {
      if (audience.name == raw) return audience;
    }
    return null;
  }
}

enum ProductStatus {
  activo('Activo'),
  inactivo('Inactivo');

  const ProductStatus(this.label);
  final String label;

  static ProductStatus fromStorage(String value) {
    for (final status in ProductStatus.values) {
      if (status.name == value) return status;
    }
    throw FormatException('Unknown product status: $value');
  }
}

class SwatchColor {
  const SwatchColor({required this.name, required this.hex});

  final String name;
  final int hex;

  Color get color => Color(hex);

  bool get isCustom => Swatches.find(name) == null;

  String get hexCode =>
      '#${hex.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  bool operator ==(Object other) =>
      other is SwatchColor && other.name == name && other.hex == hex;

  @override
  int get hashCode => Object.hash(name, hex);
}

class Swatches {
  static const negro = SwatchColor(name: 'Negro', hex: 0xFF1E1E1E);
  static const blanco = SwatchColor(name: 'Blanco', hex: 0xFFF5F5F5);
  static const gris = SwatchColor(name: 'Gris', hex: 0xFF8D8D8D);
  static const beige = SwatchColor(name: 'Beige', hex: 0xFFD4B896);
  static const marron = SwatchColor(name: 'Marrón', hex: 0xFF6B3A1F);
  static const azul = SwatchColor(name: 'Azul', hex: 0xFF3B5BA5);
  static const azulMarino = SwatchColor(name: 'Azul marino', hex: 0xFF1A365D);
  static const rojo = SwatchColor(name: 'Rojo', hex: 0xFFC62828);
  static const verde = SwatchColor(name: 'Verde', hex: 0xFF2E7D4F);
  static const rosa = SwatchColor(name: 'Rosa', hex: 0xFFE091A8);
  static const amarillo = SwatchColor(name: 'Amarillo', hex: 0xFFE6C200);
  static const bordo = SwatchColor(name: 'Bordó', hex: 0xFF7A1F32);
  static const celeste = SwatchColor(name: 'Celeste', hex: 0xFF6EC8F0);

  static const all = [
    negro,
    blanco,
    gris,
    beige,
    marron,
    azul,
    azulMarino,
    celeste,
    rojo,
    verde,
    rosa,
    amarillo,
    bordo,
  ];

  static SwatchColor? find(String name) {
    for (final color in all) {
      if (color.name == name) return color;
    }
    return null;
  }

  static SwatchColor resolve(String name, {int? hex}) {
    return find(name) ?? SwatchColor(name: name, hex: hex ?? 0xFFCCCCCC);
  }

  static int compareName(String a, String b) {
    final ia = _nameIndex(a);
    final ib = _nameIndex(b);
    if (ia != ib) return ia.compareTo(ib);
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  static int _nameIndex(String name) {
    for (var i = 0; i < all.length; i++) {
      if (all[i].name == name) return i;
    }
    return all.length;
  }
}

class ApparelSizes {
  static const letterOrder = [
    'XXXS',
    'XXS',
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    'XXXL',
    'XXXXL',
  ];

  static const all = [
    'XXS',
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    'Único',
    '36',
    '37',
    '38',
    '39',
    '40',
    '41',
    '42',
  ];

  static bool isCustom(String size) => !all.contains(size);

  static String resolve(String size) {
    for (final item in all) {
      if (item == size) return item;
    }
    return size;
  }

  static int compare(String a, String b) {
    final ka = _sortKey(a);
    final kb = _sortKey(b);
    final byGroup = ka.$1.compareTo(kb.$1);
    if (byGroup != 0) return byGroup;
    final byValue = ka.$2.compareTo(kb.$2);
    if (byValue != 0) return byValue;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  static List<String> sorted(Iterable<String> sizes) {
    return [...sizes]..sort(compare);
  }

  static (int, double) _sortKey(String size) {
    final normalized = size.trim().toUpperCase();
    final letterIndex = letterOrder.indexOf(normalized);
    if (letterIndex >= 0) return (0, letterIndex.toDouble());
    if (normalized == 'ÚNICO' || normalized == 'UNICO') return (1, 0);
    final numeric = double.tryParse(size.trim().replaceAll(',', '.'));
    if (numeric != null) return (2, numeric);
    return (3, 0);
  }
}

class ProductVariant {
  const ProductVariant({
    required this.size,
    required this.color,
    this.colorHex,
    required this.stock,
    this.skuSuffix,
  });

  final String size;
  final String color;
  final String? colorHex;
  final int stock;
  final String? skuSuffix;

  String get key => '$size|$color';

  static int compare(ProductVariant a, ProductVariant b) {
    final byColor = Swatches.compareName(a.color, b.color);
    if (byColor != 0) return byColor;
    return ApparelSizes.compare(a.size, b.size);
  }

  bool get isOut => stock <= 0;

  bool get isLow => stock > 0 && stock <= Product.lowStockThreshold;

  String get effectiveSkuSuffix =>
      skuSuffix ??
      '${size.replaceAll(' ', '').toUpperCase()}-${color.replaceAll(' ', '').toUpperCase()}';

  int get hexValue {
    final raw = (colorHex ?? '#CCCCCC').replaceAll('#', '');
    final hex = raw.length == 6 ? 'FF$raw' : raw;
    return int.parse(hex, radix: 16);
  }

  Color get swatch => Color(hexValue);

  SwatchColor get swatchColor =>
      Swatches.resolve(color, hex: colorHex == null ? null : hexValue);

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    final data = coerceStringKeyMap(map);
    return ProductVariant(
      size: data['size'] as String? ?? '',
      color: data['color'] as String? ?? '',
      colorHex: data['colorHex'] as String?,
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      skuSuffix: data['skuSuffix'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'size': size,
      'color': color,
      'colorHex': colorHex,
      'stock': stock,
      if (skuSuffix != null) 'skuSuffix': skuSuffix,
    };
  }

  ProductVariant copyWith({
    String? size,
    String? color,
    String? colorHex,
    int? stock,
    String? skuSuffix,
  }) {
    return ProductVariant(
      size: size ?? this.size,
      color: color ?? this.color,
      colorHex: colorHex ?? this.colorHex,
      stock: stock ?? this.stock,
      skuSuffix: skuSuffix ?? this.skuSuffix,
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    this.category,
    this.audience,
    required this.brand,
    required this.price,
    required this.images,
    required this.variants,
    this.equivalentSizes = const {},
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.status = ProductStatus.activo,
    this.lotId = '',
  });

  final String id;
  final String name;
  final String sku;
  final ApparelCategory? category;
  final ApparelAudience? audience;
  final String brand;
  final double price;
  final List<String> images;
  final List<ProductVariant> variants;
  final Map<String, String> equivalentSizes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final ProductStatus status;
  final String lotId;

  bool get isDeleted => deletedAt != null;

  bool get hasLot => lotId.trim().isNotEmpty;

  static const lowStockThreshold = 8;

  int get stock => variants.fold(0, (sum, variant) => sum + variant.stock);

  bool get isLowStock =>
      stock <= lowStockThreshold || variants.any((v) => v.isLow);

  String get image => images.isEmpty ? '' : images.first;

  String get categoryLabel => category?.label ?? '';

  String get audienceLabel => audience?.label ?? '';

  List<String> get sizes {
    final seen = <String>{};
    return ApparelSizes.sorted([
      for (final variant in variants)
        if (seen.add(variant.size)) variant.size,
    ]);
  }

  List<String> sizesForColor(String? colorName) {
    if (colorName == null) return sizes;
    final seen = <String>{};
    return ApparelSizes.sorted([
      for (final variant in variants)
        if (variant.color == colorName && seen.add(variant.size)) variant.size,
    ]);
  }

  List<SwatchColor> get colors {
    final seen = <String>{};
    return [
      for (final variant in variants)
        if (seen.add(variant.color)) variant.swatchColor,
    ];
  }

  String get sizeLabel => sizes.join(' / ');

  String equivalentSizeFor(String size) {
    final raw = equivalentSizes[size]?.trim() ?? '';
    return raw.isEmpty ? size : raw;
  }

  List<String> get displayedEquivalentSizes {
    return [for (final size in sizes) equivalentSizeFor(size)];
  }

  String get equivalentSizeLabel => displayedEquivalentSizes.join(' / ');

  String get colorLabel => colors.map((c) => c.name).join(' / ');

  SwatchColor get color => colors.isEmpty
      ? const SwatchColor(name: '—', hex: 0xFFCCCCCC)
      : colors.first;

  String get size => sizes.isEmpty ? '—' : sizes.first;

  bool get requiresSelection => sizes.length > 1 || colors.length > 1;

  ProductVariant? variantFor(String? size, String? colorName) {
    if (size == null || colorName == null) return null;
    for (final variant in variants) {
      if (variant.size == size && variant.color == colorName) {
        return variant;
      }
    }
    return null;
  }

  int stockForSize(String size, {String? colorName}) {
    return variants
        .where(
          (v) => v.size == size && (colorName == null || v.color == colorName),
        )
        .fold(0, (sum, v) => sum + v.stock);
  }

  int stockForColor(String colorName, {String? size}) {
    return variants
        .where((v) => v.color == colorName && (size == null || v.size == size))
        .fold(0, (sum, v) => sum + v.stock);
  }

  String variantSku(ProductVariant variant) =>
      '$sku-${variant.effectiveSkuSuffix}';

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    final data = coerceStringKeyMap(map);
    final record = SyncRecord.fromMap(id, data);
    final rawVariants = data['variants'] as List<dynamic>? ?? const [];
    final rawImages = data['images'] as List<dynamic>? ?? const [];
    final rawCategory = (data['category'] as String? ?? '').trim();
    final rawAudience = (data['audience'] as String? ?? '').trim();
    return Product(
      id: record.id,
      name: (data['name'] as String? ?? '').trim(),
      sku: (data['sku'] as String? ?? '').trim(),
      category: rawCategory.isEmpty
          ? null
          : ApparelCategory.fromStorage(rawCategory),
      audience: rawAudience.isEmpty
          ? null
          : ApparelAudience.fromStorage(rawAudience),
      brand: (data['brand'] as String? ?? '').trim(),
      price: (data['price'] as num?)?.toDouble() ?? 0,
      images: [for (final image in rawImages) '$image'],
      variants: [
        for (final variant in rawVariants)
          if (tryCoerceStringKeyMap(variant) case final map?)
            ProductVariant.fromMap(map),
      ],
      equivalentSizes: readEquivalentSizes(data['equivalentSizes']),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      deletedAt: record.deletedAt,
      status: ProductStatus.fromStorage(
        data['status'] as String? ?? ProductStatus.activo.name,
      ),
      lotId: (data['lotId'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...SyncRecord(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      ).toMap(),
      'name': name.trim(),
      'sku': sku.trim(),
      'category': category?.name ?? '',
      'audience': audience?.name ?? '',
      'brand': brand.trim(),
      'price': price,
      'images': images,
      'variants': [for (final variant in variants) variant.toMap()],
      'equivalentSizes': storedEquivalentSizes,
      'status': status.name,
      'lotId': lotId.trim(),
    };
  }

  Map<String, String> get storedEquivalentSizes {
    return {
      for (final size in sizes)
        if ((equivalentSizes[size]?.trim().isNotEmpty ?? false))
          size: equivalentSizes[size]!.trim(),
    };
  }

  static Map<String, String> readEquivalentSizes(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if ('${entry.key}'.trim().isNotEmpty &&
            '${entry.value}'.trim().isNotEmpty)
          '${entry.key}': '${entry.value}'.trim(),
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    ApparelCategory? category,
    ApparelAudience? audience,
    String? brand,
    double? price,
    List<String>? images,
    List<ProductVariant>? variants,
    Map<String, String>? equivalentSizes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    ProductStatus? status,
    String? lotId,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      audience: audience ?? this.audience,
      brand: brand ?? this.brand,
      price: price ?? this.price,
      images: images ?? this.images,
      variants: variants ?? this.variants,
      equivalentSizes: equivalentSizes ?? this.equivalentSizes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      status: status ?? this.status,
      lotId: lotId ?? this.lotId,
    );
  }
}
