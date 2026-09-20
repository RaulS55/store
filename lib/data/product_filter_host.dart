import 'package:flutter/foundation.dart';

import '../models/filters.dart';
import '../models/product.dart';

abstract class ProductFilterHost implements Listenable {
  ProductFilters get filters;
  ApparelCategory? get chipCategory;
  ApparelAudience? get chipAudience;
  List<ApparelCategory> get visibleCategories;
  List<String> get allSizes;
  List<SwatchColor> get allColors;
  List<String> get allBrands;

  void applyFilters(ProductFilters next);
  void clearFilters();
  void selectChipCategory(ApparelCategory? category);
  void selectChipAudience(ApparelAudience? audience);
}
