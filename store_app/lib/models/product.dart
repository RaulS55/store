import 'package:flutter/material.dart';

enum ApparelCategory {
  remeras('Remeras'),
  pantalones('Pantalones'),
  calzado('Calzado'),
  abrigos('Abrigos'),
  buzos('Buzos'),
  camperas('Camperas'),
  vestidos('Vestidos'),
  shorts('Shorts'),
  musculosas('Musculosas'),
  poleras('Poleras'),
  camisas('Camisas'),
  tops('Tops'),
  accesorios('Accesorios');

  const ApparelCategory(this.label);
  final String label;

  ApparelCategory get chipFamily {
    switch (this) {
      case ApparelCategory.camperas:
      case ApparelCategory.abrigos:
        return ApparelCategory.abrigos;
      case ApparelCategory.buzos:
        return ApparelCategory.buzos;
      case ApparelCategory.remeras:
      case ApparelCategory.musculosas:
      case ApparelCategory.poleras:
      case ApparelCategory.camisas:
      case ApparelCategory.tops:
        return ApparelCategory.remeras;
      case ApparelCategory.pantalones:
      case ApparelCategory.shorts:
        return ApparelCategory.pantalones;
      case ApparelCategory.calzado:
        return ApparelCategory.calzado;
      case ApparelCategory.vestidos:
      case ApparelCategory.accesorios:
        return this;
    }
  }
}

enum ProductStatus {
  activo('Activo'),
  inactivo('Inactivo');

  const ProductStatus(this.label);
  final String label;
}

class SwatchColor {
  const SwatchColor({required this.name, required this.hex});

  final String name;
  final int hex;

  Color get color => Color(hex);

  @override
  bool operator ==(Object other) =>
      other is SwatchColor && other.name == name && other.hex == hex;

  @override
  int get hashCode => Object.hash(name, hex);
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

  SwatchColor get swatchColor => SwatchColor(name: color, hex: hexValue);

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
    required this.category,
    required this.brand,
    required this.price,
    required this.images,
    required this.variants,
    this.status = ProductStatus.activo,
  });

  final String id;
  final String name;
  final String sku;
  final ApparelCategory category;
  final String brand;
  final double price;
  final List<String> images;
  final List<ProductVariant> variants;
  final ProductStatus status;

  static const lowStockThreshold = 8;

  int get stock => variants.fold(0, (sum, variant) => sum + variant.stock);

  bool get isLowStock =>
      stock <= lowStockThreshold || variants.any((v) => v.isLow);

  String get image => images.isEmpty ? '' : images.first;

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

  String get colorLabel => colors.map((c) => c.name).join(' / ');

  SwatchColor get color =>
      colors.isEmpty ? const SwatchColor(name: '—', hex: 0xFFCCCCCC) : colors.first;

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
          (v) =>
              v.size == size && (colorName == null || v.color == colorName),
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

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    ApparelCategory? category,
    String? brand,
    double? price,
    List<String>? images,
    List<ProductVariant>? variants,
    ProductStatus? status,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      price: price ?? this.price,
      images: images ?? this.images,
      variants: variants ?? this.variants,
      status: status ?? this.status,
    );
  }
}
