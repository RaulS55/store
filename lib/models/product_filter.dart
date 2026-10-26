import 'filters.dart';
import 'product.dart';

bool matchesProductFilters({
  required Product product,
  required String searchQuery,
  required Iterable<ApparelCategory> visibleCategories,
  required Iterable<ApparelAudience> visibleAudiences,
  ApparelCategory? chipCategory,
  ApparelAudience? chipAudience,
  required ProductFilters filters,
  bool listOutOfStock = false,
}) {
  final q = searchQuery.trim().toLowerCase();
  if (q.isNotEmpty) {
    final hay =
        '${product.name} ${product.sku} ${product.brand} ${product.audienceLabel}'
            .toLowerCase();
    if (!hay.contains(q)) return false;
  }
  if (product.isOutOfStock &&
      !listOutOfStock &&
      !filters.includeOutOfStock &&
      !productMatchesNameOrCode(product, q)) {
    return false;
  }
  final category = product.category;
  if (category != null &&
      !visibleCategories.contains(category) &&
      !(product.isOutOfStock && productMatchesNameOrCode(product, q))) {
    return false;
  }
  if (chipCategory != null &&
      category != chipCategory &&
      category?.chipFamily != chipCategory) {
    return false;
  }
  if (filters.categories.isNotEmpty &&
      (category == null || !filters.categories.contains(category))) {
    return false;
  }
  final audiences = visibleAudiences.toSet();
  if (audiences.length >= 2) {
    if (chipAudience != null &&
        audiences.contains(chipAudience) &&
        product.audience != chipAudience) {
      return false;
    }
    final selectedAudiences = filters.audiences.intersection(audiences);
    if (selectedAudiences.isNotEmpty &&
        (product.audience == null ||
            !selectedAudiences.contains(product.audience))) {
      return false;
    }
  }
  if (filters.sizes.isNotEmpty &&
      product.sizes.toSet().intersection(filters.sizes).isEmpty) {
    return false;
  }
  if (filters.colorNames.isNotEmpty &&
      product.colors
          .map((c) => c.name)
          .toSet()
          .intersection(filters.colorNames)
          .isEmpty) {
    return false;
  }
  if (filters.brands.isNotEmpty &&
      (product.brand.trim().isEmpty ||
          !filters.brands.contains(product.brand))) {
    return false;
  }
  if (filters.onlyLowStock &&
      (product.isOutOfStock
          ? !listOutOfStock && !filters.includeOutOfStock
          : !product.isLowStock)) {
    return false;
  }
  if (filters.minPrice != null && product.price < filters.minPrice!) {
    return false;
  }
  if (filters.maxPrice != null && product.price > filters.maxPrice!) {
    return false;
  }
  return true;
}

bool productMatchesNameOrCode(Product product, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return false;
  return product.name.toLowerCase().contains(q) ||
      product.sku.toLowerCase().contains(q);
}

List<Product> withOutOfStockLast(Iterable<Product> products) {
  final inStock = <Product>[];
  final outOfStock = <Product>[];
  for (final product in products) {
    if (product.isOutOfStock) {
      outOfStock.add(product);
    } else {
      inStock.add(product);
    }
  }
  return [...inStock, ...outOfStock];
}

List<String> brandsOf(Iterable<Product> products) {
  final seen = <String>{};
  final list = <String>[];
  for (final product in products) {
    final brand = product.brand.trim();
    if (brand.isEmpty) continue;
    if (!seen.add(brand.toLowerCase())) continue;
    list.add(brand);
  }
  list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}

List<String> sizesOf(Iterable<Product> products) {
  return ApparelSizes.sorted({
    for (final product in products) ...product.sizes,
  });
}

List<ApparelAudience> audiencesOf(Iterable<Product> products) {
  final counts = <ApparelAudience, int>{};
  for (final product in products) {
    final audience = product.audience;
    if (audience == null) continue;
    counts[audience] = (counts[audience] ?? 0) + 1;
  }
  final list = counts.keys.toList();
  list.sort((a, b) {
    final byCount = counts[b]!.compareTo(counts[a]!);
    if (byCount != 0) return byCount;
    return a.index.compareTo(b.index);
  });
  return list;
}

List<SwatchColor> colorsOf(Iterable<Product> products) {
  final seen = <String>{};
  final list = <SwatchColor>[];
  for (final product in products) {
    for (final color in product.colors) {
      if (seen.add(color.name)) list.add(color);
    }
  }
  return list;
}
