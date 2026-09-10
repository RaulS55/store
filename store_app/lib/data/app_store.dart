import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/filters.dart';
import '../models/order.dart';
import '../models/product.dart';
import 'mock_data.dart';

class AppStore extends ChangeNotifier {
  AppStore() {
    _products = MockCatalog.products();
    _customers = List<Customer>.from(MockCatalog.customers());
    _seedOrders();
  }

  ThemeMode themeMode = ThemeMode.light;
  late List<Product> _products;
  late List<Customer> _customers;
  final List<DraftOrder> orders = [];
  final List<DraftOrder> closedOrders = [];

  String searchQuery = '';
  ApparelCategory? chipCategory;
  ProductFilters filters = const ProductFilters();
  StockViewMode viewMode = StockViewMode.cards;
  StockSort sort = StockSort.recent;
  int page = 0;
  int pageSize = 12;

  int _orderSeq = 10058;
  int _draftSeq = 0;
  int _customerSeq = 4;
  String? activeOrderId;

  String sessionUser = 'Valeria Soto';
  String sessionRole = 'Administradora';

  List<Product> get products => List.unmodifiable(_products);
  List<Customer> get customers => List.unmodifiable(_customers);

  DraftOrder? get activeOrder {
    if (activeOrderId == null) return null;
    for (final order in orders) {
      if (order.id == activeOrderId) return order;
    }
    return null;
  }

  int get cartCount =>
      orders.fold(0, (sum, order) => sum + order.itemCount);

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

  Customer? customerById(String id) {
    for (final customer in _customers) {
      if (customer.id == id) return customer;
    }
    return null;
  }

  DraftOrder? orderById(String id) {
    for (final order in orders) {
      if (order.id == id) return order;
    }
    for (final order in closedOrders) {
      if (order.id == id) return order;
    }
    return null;
  }

  List<DraftOrder> ordersForCustomer(String customerId) {
    final list = [
      ...orders.where((order) => order.customer.id == customerId),
      ...closedOrders.where((order) => order.customer.id == customerId),
    ];
    list.sort((a, b) {
      if (a.isClosed != b.isClosed) return a.isClosed ? 1 : -1;
      final aDate = a.closedAt ?? a.createdAt;
      final bDate = b.closedAt ?? b.createdAt;
      return bDate.compareTo(aDate);
    });
    return list;
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

  void setActiveOrder(String? id) {
    if (id != null && !orders.any((order) => order.id == id)) return;
    if (activeOrderId == id) return;
    activeOrderId = id;
    notifyListeners();
  }

  DraftOrder createOrder(Customer customer) {
    _orderSeq += 1;
    _draftSeq += 1;
    final order = DraftOrder(
      id: 'o$_draftSeq',
      orderNumber: 'PED-$_orderSeq',
      customer: customer,
    );
    orders.insert(0, order);
    activeOrderId = order.id;
    notifyListeners();
    return order;
  }

  Customer addCustomer({
    required String name,
    String? phone,
    String? cuit,
    TaxCondition? taxCondition,
    String? address,
  }) {
    _customerSeq += 1;
    final customer = Customer(
      id: 'c$_customerSeq',
      name: name.trim(),
      phone: _blankToNull(phone),
      cuit: _blankToNull(cuit),
      taxCondition: taxCondition,
      address: _blankToNull(address),
    );
    _customers.insert(0, customer);
    notifyListeners();
    return customer;
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  void setCustomerPhone(String customerId, String phone) {
    final next = _blankToNull(phone);
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index >= 0) {
      _customers[index] = _customers[index].copyWith(phone: next);
    }
    for (final order in [...orders, ...closedOrders]) {
      if (order.customer.id == customerId) {
        order.customer = order.customer.copyWith(phone: next);
      }
    }
    notifyListeners();
  }

  void selectCustomer(String orderId, Customer customer) {
    final order = orderById(orderId);
    if (order == null || order.isClosed) return;
    order.customer = customer;
    notifyListeners();
  }

  bool addToOrder(
    Product product,
    ProductVariant variant, {
    int quantity = 1,
    String? orderId,
  }) {
    if (variant.stock <= 0) return false;
    final order = orderById(orderId ?? activeOrderId ?? '');
    if (order == null || order.isClosed) return false;
    final live = productById(product.id)?.variantFor(variant.size, variant.color);
    final available = live?.stock ?? variant.stock;
    final index =
        order.lines.indexWhere((l) => l.lineKey == '${product.id}::${variant.key}');
    if (index >= 0) {
      final nextQty = (order.lines[index].quantity + quantity).clamp(1, available);
      order.lines[index] = order.lines[index].copyWith(quantity: nextQty);
    } else {
      order.lines.add(
        OrderLine(
          product: product,
          variant: variant,
          quantity: quantity.clamp(1, available),
        ),
      );
    }
    order.status = OrderStatus.borrador;
    activeOrderId = order.id;
    notifyListeners();
    return true;
  }

  void setLineQty(String orderId, String lineKey, int quantity) {
    final order = orderById(orderId);
    if (order == null || order.isClosed) return;
    final index = order.lines.indexWhere((l) => l.lineKey == lineKey);
    if (index < 0) return;
    if (quantity <= 0) {
      order.lines.removeAt(index);
    } else {
      final line = order.lines[index];
      final live = productById(line.product.id)
          ?.variantFor(line.variant.size, line.variant.color);
      final max = live?.stock ?? line.variant.stock;
      order.lines[index] = line.copyWith(quantity: quantity.clamp(1, max));
    }
    notifyListeners();
  }

  void removeLine(String orderId, String lineKey) {
    final order = orderById(orderId);
    if (order == null || order.isClosed) return;
    order.lines.removeWhere((l) => l.lineKey == lineKey);
    notifyListeners();
  }

  bool closeOrder(String orderId) {
    final order = orderById(orderId);
    if (order == null || order.isClosed || order.lines.isEmpty) return false;
    for (final line in order.lines) {
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
    order.status = OrderStatus.cerrado;
    order.closedAt = DateTime.now();
    orders.removeWhere((item) => item.id == orderId);
    closedOrders.insert(0, order);
    if (activeOrderId == orderId) {
      activeOrderId = orders.isEmpty ? null : orders.first.id;
    }
    notifyListeners();
    return true;
  }

  void _seedOrders() {
    final monica = _customers[0];
    final abril = _customers[1];
    final ana = _customers[3];
    final polo = _products.firstWhere((p) => p.id == 'p20');
    final palazzo = _products.firstWhere((p) => p.id == 'p21');
    final bag = _products.firstWhere((p) => p.id == 'p22');
    final jeans = _products.firstWhere((p) => p.id == 'p1');
    final hoodie = _products.firstWhere((p) => p.id == 'p6');
    final dress = _products.firstWhere((p) => p.id == 'p12');
    final tee = _products.firstWhere((p) => p.id == 'p5');

    orders.addAll([
      DraftOrder(
        id: _nextDraftId(),
        orderNumber: 'PED-$_orderSeq',
        customer: monica,
        lines: [
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
        ],
      ),
      DraftOrder(
        id: _nextDraftId(),
        orderNumber: 'PED-${_orderSeq + 1}',
        customer: abril,
        lines: [
          OrderLine(
            product: jeans,
            variant: jeans.variantFor('38', 'Azul')!,
            quantity: 2,
          ),
          OrderLine(
            product: hoodie,
            variant: hoodie.variantFor('L', 'Beige arena')!,
            quantity: 1,
          ),
        ],
      ),
      DraftOrder(
        id: _nextDraftId(),
        orderNumber: 'PED-${_orderSeq + 2}',
        customer: ana,
        lines: [
          OrderLine(
            product: dress,
            variant: dress.variantFor('M', 'Crema')!,
            quantity: 1,
          ),
          OrderLine(
            product: tee,
            variant: tee.variantFor('M', 'Negro')!,
            quantity: 3,
          ),
        ],
      ),
    ]);
    final sur = _customers[2];
    closedOrders.addAll([
      DraftOrder(
        id: _nextDraftId(),
        orderNumber: 'PED-10040',
        customer: monica,
        status: OrderStatus.cerrado,
        createdAt: DateTime(2026, 8, 28, 11, 15),
        closedAt: DateTime(2026, 8, 28, 12, 40),
        lines: [
          OrderLine(
            product: tee,
            variant: tee.variantFor('S', 'Negro')!,
            quantity: 2,
          ),
          OrderLine(
            product: bag,
            variant: bag.variantFor('Único', 'Negro')!,
            quantity: 1,
          ),
        ],
      ),
      DraftOrder(
        id: _nextDraftId(),
        orderNumber: 'PED-10041',
        customer: sur,
        status: OrderStatus.cerrado,
        createdAt: DateTime(2026, 9, 2, 16, 10),
        closedAt: DateTime(2026, 9, 2, 17, 5),
        lines: [
          OrderLine(
            product: jeans,
            variant: jeans.variantFor('40', 'Azul')!,
            quantity: 3,
          ),
        ],
      ),
    ]);
    _orderSeq += 2;
    activeOrderId = orders.first.id;
  }

  String _nextDraftId() {
    _draftSeq += 1;
    return 'o$_draftSeq';
  }

  String nextSku() {
    final n = _products.length + 31;
    return 'MS-${n.toString().padLeft(4, '0')}';
  }

  String nextProductId() => 'p${DateTime.now().millisecondsSinceEpoch}';
}
