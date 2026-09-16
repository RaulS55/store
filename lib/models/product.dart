import 'package:flutter/material.dart';

import 'sync_record.dart';

enum ApparelLine { ropa, calzado }

enum ApparelCategory {
  remeras('Remeras', ApparelLine.ropa),
  musculosas('Musculosas', ApparelLine.ropa),
  poleras('Poleras', ApparelLine.ropa),
  camisas('Camisas', ApparelLine.ropa),
  chombas('Chombas', ApparelLine.ropa),
  tops('Tops', ApparelLine.ropa),
  bodies('Bodies', ApparelLine.ropa),
  buzos('Buzos', ApparelLine.ropa),
  sweaters('Sweaters', ApparelLine.ropa),
  cardigans('Cardigans', ApparelLine.ropa),
  camperas('Camperas', ApparelLine.ropa),
  abrigos('Abrigos', ApparelLine.ropa),
  blazers('Blazers', ApparelLine.ropa),
  chalecos('Chalecos', ApparelLine.ropa),
  pantalones('Pantalones', ApparelLine.ropa),
  jeans('Jeans', ApparelLine.ropa),
  shorts('Shorts', ApparelLine.ropa),
  faldas('Faldas', ApparelLine.ropa),
  vestidos('Vestidos', ApparelLine.ropa),
  enteritos('Enteritos', ApparelLine.ropa),
  conjuntos('Conjuntos', ApparelLine.ropa),
  pijamas('Pijamas', ApparelLine.ropa),
  ropaInterior('Ropa interior', ApparelLine.ropa),
  trajesDeBano('Trajes de baño', ApparelLine.ropa),
  medias('Medias', ApparelLine.ropa),
  gorras('Gorras', ApparelLine.ropa),
  bufandas('Bufandas', ApparelLine.ropa),
  accesorios('Accesorios', ApparelLine.ropa),
  zapatillas('Zapatillas', ApparelLine.calzado),
  zapatos('Zapatos', ApparelLine.calzado),
  botas('Botas', ApparelLine.calzado),
  botinetas('Botinetas', ApparelLine.calzado),
  borcegos('Borcegos', ApparelLine.calzado),
  sandalias('Sandalias', ApparelLine.calzado),
  chatitas('Chatitas', ApparelLine.calzado),
  mocasines('Mocasines', ApparelLine.calzado),
  zuecos('Zuecos', ApparelLine.calzado),
  alpargatas('Alpargatas', ApparelLine.calzado),
  ojotas('Ojotas', ApparelLine.calzado),
  pantuflas('Pantuflas', ApparelLine.calzado),
  tacos('Tacos', ApparelLine.calzado),
  botasDeLluvia('Botas de lluvia', ApparelLine.calzado),
  calzado('Calzado', ApparelLine.calzado);

  const ApparelCategory(this.label, this.line);
  final String label;
  final ApparelLine line;

  static ApparelCategory fromStorage(String value) {
    final category = tryFromStorage(value);
    if (category == null) {
      throw FormatException('Unknown category: $value');
    }
    return category;
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

  static List<ApparelCategory> forLine(ApparelLine line) {
    return [
      for (final category in values)
        if (category.line == line) category,
    ];
  }

  ApparelCategory get chipFamily => this;
}

enum ApparelAudience {
  hombre('Hombre'),
  mujer('Mujer'),
  infantil('Infantil'),
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

  static const all = [
    negro,
    blanco,
    gris,
    beige,
    marron,
    azul,
    azulMarino,
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
}

class ApparelSizes {
  static const all = [
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
    return ProductVariant(
      size: map['size'] as String? ?? '',
      color: map['color'] as String? ?? '',
      colorHex: map['colorHex'] as String?,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      skuSuffix: map['skuSuffix'] as String?,
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

  bool get isDeleted => deletedAt != null;

  static const lowStockThreshold = 8;

  int get stock => variants.fold(0, (sum, variant) => sum + variant.stock);

  bool get isLowStock =>
      stock <= lowStockThreshold || variants.any((v) => v.isLow);

  String get image => images.isEmpty ? '' : images.first;

  String get categoryLabel => category?.label ?? '';

  String get audienceLabel => audience?.label ?? '';

  List<String> get sizes {
    final seen = <String>{};
    return [
      for (final variant in variants)
        if (seen.add(variant.size)) variant.size,
    ];
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
    final record = SyncRecord.fromMap(id, map);
    final rawVariants = map['variants'] as List<dynamic>? ?? const [];
    final rawImages = map['images'] as List<dynamic>? ?? const [];
    final rawCategory = (map['category'] as String? ?? '').trim();
    final rawAudience = (map['audience'] as String? ?? '').trim();
    return Product(
      id: record.id,
      name: (map['name'] as String? ?? '').trim(),
      sku: (map['sku'] as String? ?? '').trim(),
      category: rawCategory.isEmpty
          ? null
          : ApparelCategory.fromStorage(rawCategory),
      audience: rawAudience.isEmpty
          ? null
          : ApparelAudience.fromStorage(rawAudience),
      brand: (map['brand'] as String? ?? '').trim(),
      price: (map['price'] as num?)?.toDouble() ?? 0,
      images: [for (final image in rawImages) '$image'],
      variants: [
        for (final variant in rawVariants)
          if (variant is Map)
            ProductVariant.fromMap(Map<String, dynamic>.from(variant)),
      ],
      equivalentSizes: readEquivalentSizes(map['equivalentSizes']),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      deletedAt: record.deletedAt,
      status: ProductStatus.fromStorage(
        map['status'] as String? ?? ProductStatus.activo.name,
      ),
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
    );
  }
}
