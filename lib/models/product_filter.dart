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
  Iterable<String> catalogSizes = const [],
}) {
  final q = searchQuery.trim().toLowerCase();
  final sizeQuery = catalogSizeQuery(q, catalogSizes);
  if (q.isNotEmpty) {
    final matches = sizeQuery != null
        ? productMatchesSize(product, q)
        : productMatchesText(product, q);
    if (!matches) return false;
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

bool productMatchesText(Product product, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return false;
  final hay =
      '${product.name} ${product.sku} ${product.brand} ${product.audienceLabel}'
          .toLowerCase();
  return hay.contains(q) || product.matchesCodeQuery(q);
}

bool productMatchesSize(Product product, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return false;
  return product.sizes.any((size) => size.trim().toLowerCase() == q);
}

String? catalogSizeQuery(String query, Iterable<String> sizes) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return null;
  for (final size in sizes) {
    if (size.trim().toLowerCase() == q) return size.trim();
  }
  return null;
}

Set<String> sizeFocus({
  required String searchQuery,
  required Iterable<String> catalogSizes,
  required Set<String> selectedSizes,
}) {
  final searched = catalogSizeQuery(searchQuery, catalogSizes);
  if (searched == null) return selectedSizes;
  return {...selectedSizes, searched};
}

bool productMatchesNameOrCode(Product product, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return false;
  return product.name.toLowerCase().contains(q) || product.matchesCodeQuery(q);
}

int compareProductsByUpdate(Product a, Product b) {
  final byUpdate = b.updatedAt.compareTo(a.updatedAt);
  if (byUpdate != 0) return byUpdate;
  return b.id.compareTo(a.id);
}

List<Product> withOutOfStockLast(
  Iterable<Product> products, {
  Set<String> sizes = const {},
}) {
  final inStock = <Product>[];
  final outOfStock = <Product>[];
  for (final product in products) {
    if (product.isOutOfStock || product.sizesMissingStock(sizes).isNotEmpty) {
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
