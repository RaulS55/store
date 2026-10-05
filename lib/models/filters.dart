import 'product.dart';

enum StockViewMode { cards, table }

enum StockSort {
  recent('Más recientes'),
  name('Nombre'),
  priceAsc('Precio: menor a mayor'),
  priceDesc('Precio: mayor a menor'),
  stockAsc('Menor stock');

  const StockSort(this.label);
  final String label;
}

class ProductFilters {
  const ProductFilters({
    this.categories = const {},
    this.audiences = const {},
    this.sizes = const {},
    this.colorNames = const {},
    this.brands = const {},
    this.onlyLowStock = false,
    this.onlyOutOfStock = false,
    this.minPrice,
    this.maxPrice,
  });

  final Set<ApparelCategory> categories;
  final Set<ApparelAudience> audiences;
  final Set<String> sizes;
  final Set<String> colorNames;
  final Set<String> brands;
  final bool onlyLowStock;
  final bool onlyOutOfStock;
  final double? minPrice;
  final double? maxPrice;

  bool get isEmpty =>
      categories.isEmpty &&
      audiences.isEmpty &&
      sizes.isEmpty &&
      colorNames.isEmpty &&
      brands.isEmpty &&
      !onlyLowStock &&
      !onlyOutOfStock &&
      minPrice == null &&
      maxPrice == null;

  int get activeCount {
    var n = 0;
    if (categories.isNotEmpty) n++;
    if (audiences.isNotEmpty) n++;
    if (sizes.isNotEmpty) n++;
    if (colorNames.isNotEmpty) n++;
    if (brands.isNotEmpty) n++;
    if (onlyLowStock) n++;
    if (onlyOutOfStock) n++;
    if (minPrice != null || maxPrice != null) n++;
    return n;
  }

  ProductFilters copyWith({
    Set<ApparelCategory>? categories,
    Set<ApparelAudience>? audiences,
    Set<String>? sizes,
    Set<String>? colorNames,
    Set<String>? brands,
    bool? onlyLowStock,
    bool? onlyOutOfStock,
    double? minPrice,
    double? maxPrice,
    bool clearPrices = false,
  }) {
    return ProductFilters(
      categories: categories ?? this.categories,
      audiences: audiences ?? this.audiences,
      sizes: sizes ?? this.sizes,
      colorNames: colorNames ?? this.colorNames,
      brands: brands ?? this.brands,
      onlyLowStock: onlyLowStock ?? this.onlyLowStock,
      onlyOutOfStock: onlyOutOfStock ?? this.onlyOutOfStock,
      minPrice: clearPrices ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrices ? null : (maxPrice ?? this.maxPrice),
    );
  }
}
