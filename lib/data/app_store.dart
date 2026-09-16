import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/company.dart';
import '../models/customer.dart';
import '../models/filters.dart';
import '../models/order.dart';
import '../models/product.dart';
import 'customer_access.dart';
import 'image_access.dart';
import 'image_compress.dart';
import 'product_access.dart';

class AppStore extends ChangeNotifier {
  AppStore({
    ProductAccess? products,
    CustomerAccess? customers,
    ImageAccess? images,
    void Function(String message)? log,
  }) : _productAccess = products,
       _customerAccess = customers,
       _imageAccess = images,
       _log = log ?? debugPrint;

  final ProductAccess? _productAccess;
  final CustomerAccess? _customerAccess;
  final ImageAccess? _imageAccess;
  final void Function(String message) _log;
  StreamSubscription<List<Product>>? _productsSub;
  StreamSubscription<List<Customer>>? _customersSub;
  String? _companyId;
  final Map<String, Uint8List> _imageBytes = {};

  ThemeMode themeMode = ThemeMode.light;
  List<Product> _products = [];
  List<Customer> _customers = [];
  final List<DraftOrder> orders = [];
  final List<DraftOrder> closedOrders = [];

  String searchQuery = '';
  ApparelCategory? chipCategory;
  ProductFilters filters = const ProductFilters();
  StockViewMode viewMode = StockViewMode.cards;
  StockSort sort = StockSort.recent;
  int page = 0;
  int pageSize = 12;

  int _orderSeq = 0;
  int _draftSeq = 0;
  int _customerSeq = 0;
  String? activeOrderId;

  bool ivaEnabled = false;
  double ivaPercent = 21;
  CompanyRubro rubro = CompanyRubro.ambos;

  List<Product> get products => List.unmodifiable(_products);
  List<Customer> get customers => List.unmodifiable(_customers);

  List<ApparelCategory> get visibleCategories {
    switch (rubro) {
      case CompanyRubro.ropa:
        return ApparelCategory.forLine(ApparelLine.ropa);
      case CompanyRubro.calzado:
        return ApparelCategory.forLine(ApparelLine.calzado);
      case CompanyRubro.ambos:
        return ApparelCategory.values;
    }
  }

  List<ApparelCategory> categoryChoices({ApparelCategory? current}) {
    final visible = visibleCategories;
    if (current == null || visible.contains(current)) return visible;
    return [...visible, current];
  }

  void bindCompany(String? companyId) {
    if (_companyId == companyId) return;
    _productsSub?.cancel();
    _customersSub?.cancel();
    _productsSub = null;
    _customersSub = null;
    _companyId = companyId;
    _products = [];
    _customers = [];
    _imageBytes.clear();
    notifyListeners();
    if (companyId == null) return;
    final productAccess = _productAccess;
    if (productAccess != null) {
      _productsSub = productAccess
          .watchProducts(companyId)
          .listen(
            (list) {
              _products = [
                for (final product in list)
                  if (!product.isDeleted) product,
              ];
              notifyListeners();
            },
            onError: (Object error) {
              _log('Products watch failed: $error');
            },
          );
    }
    final customerAccess = _customerAccess;
    if (customerAccess != null) {
      _customersSub = customerAccess
          .watchCustomers(companyId)
          .listen(
            (list) {
              _customers = [
                for (final customer in list)
                  if (!customer.isDeleted) customer,
              ];
              notifyListeners();
            },
            onError: (Object error) {
              _log('Customers watch failed: $error');
            },
          );
    }
  }

  Product _stamp(Product product) {
    final now = DateTime.now().toUtc();
    final existing = productById(product.id);
    return product.copyWith(
      createdAt: existing?.createdAt ?? product.createdAt,
      updatedAt: now,
      deletedAt: existing?.deletedAt ?? product.deletedAt,
    );
  }

  Future<void> _persist(Product product) async {
    final companyId = _companyId;
    final access = _productAccess;
    if (companyId == null || access == null) return;
    await access.saveProduct(companyId, product);
  }

  Customer _stampCustomer(Customer customer) {
    final now = DateTime.now().toUtc();
    final existing = customerById(customer.id);
    return customer.copyWith(
      createdAt: existing?.createdAt ?? customer.createdAt,
      updatedAt: now,
      deletedAt: existing?.deletedAt ?? customer.deletedAt,
    );
  }

  Future<void> _persistCustomer(Customer customer) async {
    final companyId = _companyId;
    final access = _customerAccess;
    if (companyId == null || access == null) return;
    await access.saveCustomer(companyId, customer);
  }

  void _syncCustomerInOrders(Customer customer) {
    for (final order in [...orders, ...closedOrders]) {
      if (order.customer.id == customer.id) {
        order.customer = customer;
      }
    }
  }

  DraftOrder? get activeOrder {
    if (activeOrderId == null) return null;
    for (final order in orders) {
      if (order.id == activeOrderId) return order;
    }
    return null;
  }

  int get cartCount => orders.fold(0, (sum, order) => sum + order.itemCount);

  List<String> get allBrands {
    final set = _products.map((p) => p.brand).toSet().toList()..sort();
    return set;
  }

  List<String> get allSizes {
    const preferred = ApparelSizes.all;
    final extra = <String>{for (final product in _products) ...product.sizes};
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
        final hay = '${product.name} ${product.sku} ${product.brand}'
            .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (!visibleCategories.contains(product.category)) return false;
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
      if (filters.brands.isNotEmpty &&
          !filters.brands.contains(product.brand)) {
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

  bool isSkuInUse(String sku, {String? excludingProductId}) {
    final needle = sku.trim().toLowerCase();
    if (needle.isEmpty) return false;
    for (final product in _products) {
      if (product.isDeleted) continue;
      if (product.id == excludingProductId) continue;
      if (product.sku.trim().toLowerCase() == needle) return true;
    }
    return false;
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
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  void setIvaEnabled(bool enabled) {
    if (ivaEnabled == enabled) return;
    ivaEnabled = enabled;
    _applyIvaToActiveOrders();
    notifyListeners();
  }

  void setIvaPercent(double percent) {
    final next = (percent.clamp(0, 100) * 100).round() / 100;
    if (ivaPercent == next) return;
    ivaPercent = next;
    _applyIvaToActiveOrders();
    notifyListeners();
  }

  void setRubro(CompanyRubro next) {
    if (rubro == next) return;
    rubro = next;
    final allowed = visibleCategories.toSet();
    if (chipCategory != null && !allowed.contains(chipCategory)) {
      chipCategory = null;
    }
    if (filters.categories.isNotEmpty) {
      filters = filters.copyWith(
        categories: filters.categories.intersection(allowed),
      );
    }
    page = 0;
    notifyListeners();
  }

  void _applyIvaToActiveOrders() {
    for (final order in orders) {
      order.ivaEnabled = ivaEnabled;
      order.ivaPercent = ivaPercent;
    }
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

  Future<void> upsertProduct(Product product) async {
    final next = _stamp(product);
    final index = _products.indexWhere((p) => p.id == next.id);
    if (index >= 0) {
      _products[index] = next;
    } else {
      _products.insert(0, next);
    }
    notifyListeners();
    await _persist(next);
  }

  Future<void> deleteProduct(String productId) async {
    final existing = productById(productId);
    if (existing == null) return;
    final next = _stamp(existing.copyWith(deletedAt: DateTime.now().toUtc()));
    await _persist(next);
    _products.removeWhere((product) => product.id == productId);
    for (final url in existing.images) {
      _imageBytes.remove(url);
    }
    notifyListeners();
    final companyId = _companyId;
    final access = _imageAccess;
    if (companyId == null || access == null) return;
    try {
      await access.deleteProductImages(
        companyId: companyId,
        productId: productId,
      );
    } catch (error) {
      _log('Product images delete failed: $error');
    }
  }

  Future<CompressedImage> prepareProductImage(Uint8List bytes) async {
    _log('Image compress start originalBytes=${bytes.lengthInBytes}');
    final compressed = await compressProductImage(bytes);
    _log(
      imageUploadSizeLog(
        originalByteCount: compressed.originalByteCount,
        compressedByteCount: compressed.compressedByteCount,
      ),
    );
    return compressed;
  }

  Future<String> uploadProductImage({
    required String productId,
    required Uint8List bytes,
  }) async {
    final companyId = _companyId;
    final access = _imageAccess;
    if (companyId == null || access == null) {
      throw const ImageUploadException('No hay una empresa activa.');
    }
    final fileName = '${DateTime.now().microsecondsSinceEpoch}.jpg';
    final url = await access.uploadProductImage(
      companyId: companyId,
      productId: productId,
      fileName: fileName,
      bytes: bytes,
      contentType: 'image/jpeg',
    );
    _imageBytes[url] = bytes;
    return url;
  }

  Uint8List? cachedProductImage(String url) => _imageBytes[url];

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
    final next = _stamp(product.copyWith(variants: variants));
    _products[index] = next;
    notifyListeners();
    unawaited(_persist(next));
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
      ivaEnabled: ivaEnabled,
      ivaPercent: ivaPercent,
    );
    orders.insert(0, order);
    activeOrderId = order.id;
    notifyListeners();
    return order;
  }

  Future<Customer> addCustomer({
    required String name,
    String? phone,
    String? cuit,
    TaxCondition? taxCondition,
    String? address,
  }) async {
    final now = DateTime.now().toUtc();
    final customer = Customer(
      id: nextCustomerId(),
      name: name.trim(),
      phone: _blankToNull(phone),
      cuit: _blankToNull(cuit),
      taxCondition: taxCondition,
      address: _blankToNull(address),
      createdAt: now,
      updatedAt: now,
    );
    await upsertCustomer(customer);
    return customerById(customer.id) ?? customer;
  }

  Future<void> upsertCustomer(Customer customer) async {
    final next = _stampCustomer(customer);
    final index = _customers.indexWhere((item) => item.id == next.id);
    if (index >= 0) {
      _customers[index] = next;
    } else {
      _customers.insert(0, next);
    }
    _syncCustomerInOrders(next);
    notifyListeners();
    await _persistCustomer(next);
  }

  Future<void> deleteCustomer(String customerId) async {
    final existing = customerById(customerId);
    if (existing == null) return;
    final next = _stampCustomer(
      existing.copyWith(deletedAt: DateTime.now().toUtc()),
    );
    await _persistCustomer(next);
    _customers.removeWhere((customer) => customer.id == customerId);
    notifyListeners();
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> setCustomerPhone(String customerId, String phone) async {
    final nextPhone = _blankToNull(phone);
    final existing = customerById(customerId);
    if (existing == null) {
      for (final order in [...orders, ...closedOrders]) {
        if (order.customer.id == customerId) {
          order.customer = Customer(
            id: order.customer.id,
            name: order.customer.name,
            cuit: order.customer.cuit,
            taxCondition: order.customer.taxCondition,
            phone: nextPhone,
            address: order.customer.address,
            createdAt: order.customer.createdAt,
            updatedAt: DateTime.now().toUtc(),
            deletedAt: order.customer.deletedAt,
          );
        }
      }
      notifyListeners();
      return;
    }
    await upsertCustomer(
      Customer(
        id: existing.id,
        name: existing.name,
        cuit: existing.cuit,
        taxCondition: existing.taxCondition,
        phone: nextPhone,
        address: existing.address,
        createdAt: existing.createdAt,
        updatedAt: existing.updatedAt,
        deletedAt: existing.deletedAt,
      ),
    );
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
    final live = productById(
      product.id,
    )?.variantFor(variant.size, variant.color);
    final available = live?.stock ?? variant.stock;
    final index = order.lines.indexWhere(
      (l) => l.lineKey == '${product.id}::${variant.key}',
    );
    if (index >= 0) {
      final nextQty = (order.lines[index].quantity + quantity).clamp(
        1,
        available,
      );
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
      final live = productById(
        line.product.id,
      )?.variantFor(line.variant.size, line.variant.color);
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
      final variant = product?.variantFor(
        line.variant.size,
        line.variant.color,
      );
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

  String nextSku() {
    final n = _products.length + 1;
    return 'MS-${n.toString().padLeft(4, '0')}';
  }

  String nextProductId() {
    final companyId = _companyId;
    final access = _productAccess;
    if (companyId != null && access != null) {
      return access.nextProductId(companyId);
    }
    return 'p${DateTime.now().millisecondsSinceEpoch}';
  }

  String nextCustomerId() {
    final companyId = _companyId;
    final access = _customerAccess;
    if (companyId != null && access != null) {
      return access.nextCustomerId(companyId);
    }
    _customerSeq += 1;
    return 'c$_customerSeq';
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    _customersSub?.cancel();
    super.dispose();
  }
}
