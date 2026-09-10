import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/filters.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../theme/tokens.dart';
import 'mock_data.dart';

class AppStore extends ChangeNotifier {
  AppStore() {
    _products = MockCatalog.products();
    _customers = MockCatalog.customers();
    _seedDraft();
  }

  ThemeMode themeMode = ThemeMode.light;
  late List<Product> _products;
  late List<Customer> _customers;
  final List<InvoiceRecord> invoices = [];

  String searchQuery = '';
  ApparelCategory? chipCategory;
  ProductFilters filters = const ProductFilters();
  StockViewMode viewMode = StockViewMode.cards;
  StockSort sort = StockSort.recent;
  int page = 0;
  int pageSize = 12;

  String orderNumber = 'PED-10058';
  int _orderSeq = 10058;
  Customer? selectedCustomer;
  List<OrderLine> lines = [];
  PaymentMethod paymentMethod = PaymentMethod.efectivo;
  OrderStatus orderStatus = OrderStatus.borrador;

  String sessionUser = 'Valeria Soto';
  String sessionRole = 'Administradora';

  List<Product> get products => List.unmodifiable(_products);
  List<Customer> get customers => List.unmodifiable(_customers);

  int get cartCount => lines.fold(0, (sum, line) => sum + line.quantity);

  double get subtotal => lines.fold(0, (sum, line) => sum + line.lineTotal);

  double get iva => subtotal * AppIva.rate;

  double get total => subtotal + iva;

  List<String> get allBrands {
    final set = _products.map((p) => p.brand).toSet().toList()..sort();
    return set;
  }

  List<String> get allSizes {
    const preferred = [
      'XS',
      'S',
      'M',
      'L',
      'XL',
      'Único',
      '30',
      '32',
      '34',
      '36',
      '38',
      '39',
      '40',
      '41',
      '42',
    ];
    final extra = <String>{
      for (final product in _products) ...product.sizes,
    };
    return [
      ...preferred.where(extra.contains),
      ...extra.where((s) => !preferred.contains(s)).toList()..sort(),
    ];
  }

  List<SwatchColor> get allColors {
    final seen = <String>{};
    final list = <SwatchColor>[];
    for (final product in _products) {
      for (final color in product.colors) {
        if (seen.add(color.name)) list.add(color);
      }
    }
    return list;
  }

  List<Product> get filteredProducts {
    final q = searchQuery.trim().toLowerCase();
    var list = _products.where((product) {
      if (q.isNotEmpty) {
        final hay =
            '${product.name} ${product.sku} ${product.brand}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (chipCategory != null &&
          product.category != chipCategory &&
          product.category.chipFamily != chipCategory) {
        return false;
      }
      if (filters.categories.isNotEmpty &&
          !filters.categories.contains(product.category)) {
        return false;
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
      if (filters.brands.isNotEmpty && !filters.brands.contains(product.brand)) {
        return false;
      }
      if (filters.onlyLowStock && !product.isLowStock) return false;
      if (filters.minPrice != null && product.price < filters.minPrice!) {
        return false;
      }
      if (filters.maxPrice != null && product.price > filters.maxPrice!) {
        return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      switch (sort) {
        case StockSort.recent:
          return b.id.compareTo(a.id);
        case StockSort.name:
          return a.name.compareTo(b.name);
        case StockSort.priceAsc:
          return a.price.compareTo(b.price);
        case StockSort.priceDesc:
          return b.price.compareTo(a.price);
        case StockSort.stockAsc:
          return a.stock.compareTo(b.stock);
      }
    });
    return list;
  }

  int get filteredCount => filteredProducts.length;

  int get pageCount {
    final n = filteredCount;
    if (n == 0) return 1;
    return (n / pageSize).ceil();
  }

  List<Product> get pagedProducts {
    final all = filteredProducts;
    if (all.isEmpty) return const [];
    final start = (page * pageSize).clamp(0, all.length);
    final end = (start + pageSize).clamp(0, all.length);
    return all.sublist(start, end);
  }

  Product? productById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  void toggleTheme() {
    themeMode =
        themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  void setSearch(String value) {
    searchQuery = value;
    page = 0;
    notifyListeners();
  }

  void setChipCategory(ApparelCategory? category) {
    chipCategory = chipCategory == category ? null : category;
    page = 0;
    notifyListeners();
  }

  void selectChipCategory(ApparelCategory? category) {
    chipCategory = category;
    page = 0;
    notifyListeners();
  }

  void applyFilters(ProductFilters next) {
    filters = next;
    page = 0;
    notifyListeners();
  }

  void clearFilters() {
    filters = const ProductFilters();
    chipCategory = null;
    searchQuery = '';
    page = 0;
    notifyListeners();
  }

  void setViewMode(StockViewMode mode) {
    viewMode = mode;
    pageSize = mode == StockViewMode.table ? 10 : 12;
    page = 0;
    notifyListeners();
  }

  void setSort(StockSort next) {
    sort = next;
    notifyListeners();
  }

  void setPage(int next) {
    page = next.clamp(0, pageCount - 1);
    notifyListeners();
  }

  void upsertProduct(Product product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      _products[index] = product;
    } else {
      _products.insert(0, product);
    }
    notifyListeners();
  }

  void updateVariantStock(
    String productId,
    String size,
    String color, {
    required int stock,
  }) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index < 0) return;
    final product = _products[index];
    final variants = [
      for (final variant in product.variants)
        if (variant.size == size && variant.color == color)
          variant.copyWith(stock: stock.clamp(0, 999999))
        else
          variant,
    ];
    _products[index] = product.copyWith(variants: variants);
    notifyListeners();
  }

  void selectCustomer(Customer? customer) {
    selectedCustomer = customer;
    notifyListeners();
  }

  bool addToOrder(Product product, ProductVariant variant, {int quantity = 1}) {
    if (variant.stock <= 0) return false;
    final live = productById(product.id)?.variantFor(variant.size, variant.color);
    final available = live?.stock ?? variant.stock;
    final index = lines.indexWhere((l) => l.lineKey == '${product.id}::${variant.key}');
    if (index >= 0) {
      final nextQty = (lines[index].quantity + quantity).clamp(1, available);
      lines[index] = lines[index].copyWith(quantity: nextQty);
    } else {
      lines.add(
        OrderLine(
          product: product,
          variant: variant,
          quantity: quantity.clamp(1, available),
        ),
      );
    }
    orderStatus = OrderStatus.borrador;
    notifyListeners();
    return true;
  }

  void setLineQty(String lineKey, int quantity) {
    final index = lines.indexWhere((l) => l.lineKey == lineKey);
    if (index < 0) return;
    if (quantity <= 0) {
      lines.removeAt(index);
    } else {
      final line = lines[index];
      final live = productById(line.product.id)
          ?.variantFor(line.variant.size, line.variant.color);
      final max = live?.stock ?? line.variant.stock;
      lines[index] = line.copyWith(quantity: quantity.clamp(1, max));
    }
    notifyListeners();
  }

  void removeLine(String lineKey) {
    lines.removeWhere((l) => l.lineKey == lineKey);
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod method) {
    paymentMethod = method;
    notifyListeners();
  }

  bool confirmInvoice() {
    if (lines.isEmpty || selectedCustomer == null) return false;
    for (final line in lines) {
      final product = productById(line.product.id);
      final variant = product?.variantFor(line.variant.size, line.variant.color);
      if (product == null || variant == null) continue;
      updateVariantStock(
        product.id,
        variant.size,
        variant.color,
        stock: (variant.stock - line.quantity).clamp(0, 999999),
      );
    }
    invoices.insert(
      0,
      InvoiceRecord(
        orderNumber: orderNumber,
        issuedAt: DateTime.now(),
        customerName: selectedCustomer!.name,
        total: total,
        paymentMethod: paymentMethod,
      ),
    );
    orderStatus = OrderStatus.facturado;
    notifyListeners();
    _resetDraft();
    return true;
  }

  void _resetDraft() {
    _orderSeq += 1;
    orderNumber = 'PED-$_orderSeq';
    lines = [];
    paymentMethod = PaymentMethod.efectivo;
    orderStatus = OrderStatus.borrador;
    notifyListeners();
  }

  void _seedDraft() {
    selectedCustomer = _customers.first;
    final polo = _products.firstWhere((p) => p.id == 'p20');
    final palazzo = _products.firstWhere((p) => p.id == 'p21');
    final bag = _products.firstWhere((p) => p.id == 'p22');
    lines = [
      OrderLine(
        product: polo,
        variant: polo.variantFor('M', 'Óxido')!,
        quantity: 2,
      ),
      OrderLine(
        product: palazzo,
        variant: palazzo.variantFor('L', 'Beige')!,
        quantity: 1,
      ),
      OrderLine(
        product: bag,
        variant: bag.variantFor('Único', 'Negro')!,
        quantity: 1,
      ),
    ];
  }

  String nextSku() {
    final n = _products.length + 31;
    return 'MS-${n.toString().padLeft(4, '0')}';
  }

  String nextProductId() => 'p${DateTime.now().millisecondsSinceEpoch}';
}
