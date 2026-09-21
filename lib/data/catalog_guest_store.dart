import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/company.dart';
import '../models/customer.dart';
import '../models/filters.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/product_filter.dart';
import '../models/record_source.dart';
import 'company_access.dart';
import 'customer_access.dart';
import 'local/catalog_cart_cache.dart';
import 'local/hive_catalog_cache.dart';
import 'order_access.dart';
import 'order_share.dart';
import 'product_access.dart';
import 'product_filter_host.dart';
import 'product_image_cache.dart';
import 'session_exception.dart';

class CatalogSubmitResult {
  const CatalogSubmitResult({
    required this.order,
    required this.whatsappUri,
    required this.missingPhone,
  });

  final DraftOrder order;
  final Uri? whatsappUri;
  final bool missingPhone;
}

class CatalogGuestStore extends ChangeNotifier implements ProductFilterHost {
  CatalogGuestStore({
    required this.companyId,
    required CompanyAccess companies,
    required ProductAccess products,
    required CustomerAccess customers,
    required OrderAccess orders,
    CatalogCartCache? cart,
    ProductImageCache? images,
    HiveCatalogCache? local,
    this.loadTimeout = const Duration(seconds: 8),
  }) : _companies = companies,
       _products = products,
       _customers = customers,
       _orders = orders,
       _cart = cart ?? MemoryCatalogCartCache(),
       _images = images,
       _local = local {
    ready = _start();
  }

  final String companyId;
  final Duration loadTimeout;
  final CompanyAccess _companies;
  final ProductAccess _products;
  final CustomerAccess _customers;
  final OrderAccess _orders;
  final CatalogCartCache _cart;
  final ProductImageCache? _images;
  final HiveCatalogCache? _local;

  late final Future<void> ready;
  StreamSubscription<List<Product>>? _productSub;

  Company? _company;
  List<Product> _allProducts = const [];
  List<CatalogCartLine> _lines = const [];
  String searchQuery = '';
  @override
  ApparelCategory? chipCategory;
  @override
  ApparelAudience? chipAudience;
  @override
  ProductFilters filters = const ProductFilters();
  var _booted = false;
  var _busy = false;

  Company? get company => _company;
  bool get isLoading => !_booted;
  bool get notFound => _booted && _company == null;
  bool get isBusy => _busy;

  List<Product> get products {
    return [
      for (final product in _allProducts)
        if (!product.isDeleted &&
            product.status == ProductStatus.activo &&
            product.stock > 0)
          product,
    ];
  }

  CompanyRubro get rubro => _company?.rubro ?? CompanyRubro.ambos;

  @override
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

  @override
  List<String> get allBrands => brandsOf(products);

  @override
  List<String> get allSizes => sizesOf(products);

  @override
  List<SwatchColor> get allColors => colorsOf(products);

  List<Product> get visibleProducts {
    return [
      for (final product in products)
        if (matchesProductFilters(
          product: product,
          searchQuery: searchQuery,
          visibleCategories: visibleCategories,
          chipCategory: chipCategory,
          chipAudience: chipAudience,
          filters: filters,
        ))
          product,
    ];
  }

  Product? productById(String id) {
    for (final product in _allProducts) {
      if (product.id == id && !product.isDeleted) return product;
    }
    return null;
  }

  List<OrderLine> get cartLines {
    final result = <OrderLine>[];
    for (final item in _lines) {
      final product = productById(item.productId);
      if (product == null || product.status != ProductStatus.activo) continue;
      final variant = product.variantFor(item.size, item.color);
      if (variant == null || variant.stock <= 0) continue;
      final quantity = item.quantity.clamp(1, variant.stock).toInt();
      result.add(
        OrderLine(product: product, variant: variant, quantity: quantity),
      );
    }
    return result;
  }

  int get cartCount => cartLines.fold(0, (sum, line) => sum + line.quantity);

  double get cartTotal =>
      cartLines.fold(0, (sum, line) => sum + line.lineTotal);

  bool get hasCart => cartLines.isNotEmpty;

  void setSearch(String value) {
    if (searchQuery == value) return;
    searchQuery = value;
    notifyListeners();
  }

  @override
  void selectChipCategory(ApparelCategory? category) {
    chipCategory = category;
    notifyListeners();
  }

  @override
  void selectChipAudience(ApparelAudience? audience) {
    chipAudience = audience;
    notifyListeners();
  }

  @override
  void applyFilters(ProductFilters next) {
    filters = next;
    notifyListeners();
  }

  @override
  void clearFilters() {
    filters = const ProductFilters();
    chipCategory = null;
    chipAudience = null;
    searchQuery = '';
    notifyListeners();
  }

  void addToCart(Product product, ProductVariant variant, {int quantity = 1}) {
    if (variant.stock <= 0 || quantity <= 0) return;
    final key = '${product.id}::${variant.key}';
    final next = [..._lines];
    final index = next.indexWhere((line) => line.lineKey == key);
    if (index >= 0) {
      final merged = next[index].quantity + quantity;
      next[index] = next[index].copyWith(
        quantity: merged.clamp(1, variant.stock).toInt(),
      );
    } else {
      if (next.length >= 50) return;
      next.add(
        CatalogCartLine(
          productId: product.id,
          size: variant.size,
          color: variant.color,
          quantity: quantity.clamp(1, variant.stock).toInt(),
        ),
      );
    }
    _setLines(next);
  }

  void setLineQty(String lineKey, int quantity) {
    final index = _lines.indexWhere((line) => line.lineKey == lineKey);
    if (index < 0) return;
    final current = _lines[index];
    final product = productById(current.productId);
    final variant = product?.variantFor(current.size, current.color);
    final max = variant?.stock ?? current.quantity;
    if (quantity < 1 || max < 1) {
      removeLine(lineKey);
      return;
    }
    final next = [..._lines];
    next[index] = current.copyWith(quantity: quantity.clamp(1, max).toInt());
    _setLines(next);
  }

  void removeLine(String lineKey) {
    _setLines([
      for (final line in _lines)
        if (line.lineKey != lineKey) line,
    ]);
  }

  Future<void> clearCart() async {
    _lines = const [];
    await _cart.clear(companyId);
    notifyListeners();
  }

  Future<CatalogSubmitResult> submit({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.length < 2) {
      throw const SessionException('Ingresá tu nombre.');
    }
    final lines = cartLines
        .where((line) => line.variant.stock > 0)
        .map((line) {
          final max = line.variant.stock;
          return line.copyWith(quantity: line.quantity.clamp(1, max).toInt());
        })
        .where((line) => line.quantity > 0)
        .toList();
    if (lines.isEmpty) {
      throw const SessionException('Agregá al menos una prenda.');
    }
    _busy = true;
    notifyListeners();
    try {
      final now = DateTime.now().toUtc();
      final customer = Customer(
        id: _customers.nextCustomerId(companyId),
        name: trimmed,
        createdAt: now,
        updatedAt: now,
        source: RecordSource.catalog,
      );
      final orderId = _orders.nextOrderId(companyId);
      final shortId = orderId.length >= 8 ? orderId.substring(0, 8) : orderId;
      final order = DraftOrder(
        id: orderId,
        orderNumber: 'WEB-${shortId.toUpperCase()}',
        customer: customer,
        lines: lines,
        createdAt: now,
        updatedAt: now,
        ivaEnabled: false,
        source: RecordSource.catalog,
      );
      await _customers.saveCustomer(companyId, customer);
      await _orders.saveOrder(companyId, order);
      await clearCart();
      final uri = OrderShare.catalogWhatsAppUri(order, _company?.phone);
      return CatalogSubmitResult(
        order: order,
        whatsappUri: uri,
        missingPhone: uri == null,
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _start() async {
    await _hydrateLocal();
    final hasLocalCompany = _company != null;
    try {
      if (hasLocalCompany) {
        await _bindProducts().timeout(loadTimeout);
        _booted = true;
        notifyListeners();
        unawaited(_refreshCompany());
      } else {
        await Future.wait<void>([
          _refreshCompany(),
          _bindProducts(),
        ]).timeout(loadTimeout);
      }
    } catch (error, stack) {
      debugPrint('Catalog load failed: $error');
      debugPrint('$stack');
    } finally {
      _booted = true;
      notifyListeners();
    }
  }

  Future<void> _hydrateLocal() async {
    try {
      final cart = _cart;
      if (cart is HiveCatalogCartCache) {
        await cart.ensureOpen();
      }
      _lines = _cart.load(companyId);
      _company = _local?.loadCompany(companyId);
      if (_company != null || _lines.isNotEmpty) notifyListeners();
    } catch (error, stack) {
      debugPrint('Catalog local hydrate failed: $error');
      debugPrint('$stack');
    }
  }

  Future<void> _refreshCompany() async {
    try {
      final remote = await _companies.getCompany(companyId);
      _company = remote;
      if (remote != null) {
        await _local?.saveCompany(remote);
      }
      notifyListeners();
    } catch (error, stack) {
      debugPrint('Catalog company load failed: $error');
      debugPrint('$stack');
    }
  }

  Future<void> _bindProducts() async {
    final productsReady = Completer<void>();
    try {
      _productSub = _products
          .watchProducts(companyId)
          .listen(
            (list) {
              _allProducts = list;
              _pruneMissing();
              unawaited(
                _images?.prefetchProductImages(
                  products.take(24),
                  coversOnly: true,
                ),
              );
              notifyListeners();
              if (!productsReady.isCompleted) productsReady.complete();
            },
            onError: (Object error, StackTrace stack) {
              debugPrint('Catalog products failed: $error');
              debugPrint('$stack');
              if (!productsReady.isCompleted) productsReady.complete();
            },
          );
      await productsReady.future;
    } catch (error, stack) {
      debugPrint('Catalog products bind failed: $error');
      debugPrint('$stack');
      if (!productsReady.isCompleted) productsReady.complete();
    }
  }

  void _pruneMissing() {
    final next = [
      for (final line in _lines)
        if (productById(line.productId) != null) line,
    ];
    if (next.length != _lines.length) {
      _lines = next;
      unawaited(_cart.save(companyId, _lines));
    }
  }

  void _setLines(List<CatalogCartLine> next) {
    _lines = next;
    notifyListeners();
    unawaited(_cart.save(companyId, _lines));
  }

  @override
  void dispose() {
    _productSub?.cancel();
    super.dispose();
  }
}
