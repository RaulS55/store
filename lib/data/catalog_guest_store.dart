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
    this.updated = false,
    this.replacedClosed = false,
  });

  final DraftOrder order;
  final Uri? whatsappUri;
  final bool missingPhone;
  final bool updated;
  final bool replacedClosed;
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
  StreamSubscription<DraftOrder?>? _orderSub;

  Company? _company;
  List<Product> _allProducts = const [];
  List<CatalogCartLine> _pending = const [];
  List<CatalogCartLine> _requestedCache = const [];
  CatalogOpenOrder? _openOrder;
  DraftOrder? _remoteOrder;
  var _legacyOpenCart = false;
  String searchQuery = '';
  @override
  ApparelCategory? chipCategory;
  @override
  ApparelAudience? chipAudience;
  @override
  ProductFilters filters = const ProductFilters();
  var _booted = false;
  var _busy = false;
  var _alive = true;

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
    final predefined = switch (rubro) {
      CompanyRubro.ropa => ApparelCategory.forLine(ApparelLine.ropa),
      CompanyRubro.calzado => ApparelCategory.forLine(ApparelLine.calzado),
      CompanyRubro.ambos => ApparelCategory.values,
    };
    return ApparelCategory.mergeVisible(
      predefined: predefined,
      used: [
        for (final product in products)
          if (product.category != null) product.category!,
      ],
    );
  }

  @override
  List<String> get allBrands => brandsOf(products);

  @override
  List<ApparelAudience> get visibleAudiences => audiencesOf(products);

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
          visibleAudiences: visibleAudiences,
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

  List<OrderLine> get pendingCartLines => _resolvePending(_pending);

  List<OrderLine> get requestedCartLines {
    final remote = _remoteOrder;
    if (remote != null && remote.isActive) {
      return OrderLine.sorted(remote.lines);
    }
    return _resolveRequested(_requestedCache);
  }

  List<OrderLine> get cartLines => [...pendingCartLines, ...requestedCartLines];

  int get cartCount => cartLines.fold(0, (sum, line) => sum + line.quantity);

  double get pendingTotal =>
      pendingCartLines.fold(0, (sum, line) => sum + line.lineTotal);

  double get requestedTotal =>
      requestedCartLines.fold(0, (sum, line) => sum + line.lineTotal);

  double get cartTotal => pendingTotal + requestedTotal;

  bool get hasCart => cartLines.isNotEmpty;

  bool get hasPending => pendingCartLines.isNotEmpty;

  CatalogOpenOrder? get openOrder => _openOrder;

  int pendingMaxFor(String lineKey, int stock) {
    final room = stock - _requestedQty(lineKey);
    if (room < 0) return 0;
    return room;
  }

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
    final room = variant.stock - _requestedQty(key);
    if (room <= 0) return;
    final next = [..._pending];
    final index = next.indexWhere((line) => line.lineKey == key);
    if (index >= 0) {
      final merged = next[index].quantity + quantity;
      next[index] = next[index].copyWith(
        quantity: merged.clamp(1, room).toInt(),
      );
    } else {
      if (_uniqueLineCount >= 50) return;
      next.add(
        CatalogCartLine(
          productId: product.id,
          size: variant.size,
          color: variant.color,
          quantity: quantity.clamp(1, room).toInt(),
        ),
      );
    }
    _setPending(next);
  }

  void setLineQty(String lineKey, int quantity) {
    final index = _pending.indexWhere((line) => line.lineKey == lineKey);
    if (index < 0) return;
    final current = _pending[index];
    final product = productById(current.productId);
    final variant = product?.variantFor(current.size, current.color);
    final room = (variant?.stock ?? current.quantity) - _requestedQty(lineKey);
    if (quantity < 1 || room < 1) {
      removeLine(lineKey);
      return;
    }
    final next = [..._pending];
    next[index] = current.copyWith(quantity: quantity.clamp(1, room).toInt());
    _setPending(next);
  }

  void removeLine(String lineKey) {
    _setPending([
      for (final line in _pending)
        if (line.lineKey != lineKey) line,
    ]);
  }

  Future<void> clearCart() async {
    _pending = const [];
    _requestedCache = const [];
    await _cart.clear(companyId);
    notifyListeners();
  }

  Future<CatalogSubmitResult> submit({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.length < 2) {
      throw const SessionException('Ingresá tu nombre.');
    }
    final pending = pendingCartLines
        .where((line) => line.variant.stock > 0)
        .map((line) {
          final max = line.variant.stock - _requestedQty(line.lineKey);
          return line.copyWith(quantity: line.quantity.clamp(1, max).toInt());
        })
        .where((line) => line.quantity > 0)
        .toList();
    if (pending.isEmpty) {
      throw const SessionException('Agregá al menos una prenda.');
    }
    _busy = true;
    notifyListeners();
    try {
      final now = DateTime.now().toUtc();
      final open = _openOrder;
      if (open != null) {
        try {
          final order = await _writeOpenOrder(
            open: open,
            name: trimmed,
            lines: pending,
            now: now,
          );
          _setPending(const []);
          return _submitResult(order, updated: true, addedLines: pending);
        } on CatalogOrderLockedException {
          await _releaseClosedOrder();
          throw const SessionException(
            'El negocio cerró el pedido. Podés armar uno nuevo.',
          );
        }
      }
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
        lines: pending,
        createdAt: now,
        updatedAt: now,
        ivaEnabled: false,
        source: RecordSource.catalog,
      );
      await _customers.saveCustomer(companyId, customer);
      await _orders.saveOrder(companyId, order);
      _remoteOrder = order;
      _requestedCache = _cartLinesFrom(order.lines, requested: true);
      _setPending(const [], persist: false);
      await _setOpenOrder(
        CatalogOpenOrder(
          orderId: order.id,
          orderNumber: order.orderNumber,
          customerId: customer.id,
          customerName: customer.name,
          orderCreatedAt: order.createdAt,
          customerCreatedAt: customer.createdAt,
        ),
      );
      _persistCart();
      return _submitResult(order);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<DraftOrder> _writeOpenOrder({
    required CatalogOpenOrder open,
    required String name,
    required List<OrderLine> lines,
    required DateTime now,
  }) async {
    final customer = Customer(
      id: open.customerId,
      name: name,
      createdAt: open.customerCreatedAt,
      updatedAt: now,
      source: RecordSource.catalog,
    );
    final current = _remoteOrder?.lines ?? requestedCartLines;
    final merged = OrderLine.mergeAdded(current, lines);
    final order = DraftOrder(
      id: open.orderId,
      orderNumber: open.orderNumber,
      customer: customer,
      lines: lines,
      createdAt: open.orderCreatedAt,
      updatedAt: now,
      ivaEnabled: false,
      source: RecordSource.catalog,
    );
    await _orders.updateCatalogOrder(companyId, order);
    try {
      await _customers.saveCustomer(companyId, customer);
    } catch (error, stack) {
      debugPrint('Catalog customer update failed: $error');
      debugPrint('$stack');
    }
    final remote = _remoteOrder;
    if (remote != null && remote.id == open.orderId) {
      remote.customer = customer;
      remote.updatedAt = now;
      remote.lines
        ..clear()
        ..addAll(merged);
    } else {
      _remoteOrder = DraftOrder(
        id: open.orderId,
        orderNumber: open.orderNumber,
        customer: customer,
        lines: merged,
        createdAt: open.orderCreatedAt,
        updatedAt: now,
        ivaEnabled: false,
        source: RecordSource.catalog,
      );
    }
    _requestedCache = _cartLinesFrom(merged, requested: true);
    await _setOpenOrder(open.copyWith(customerName: customer.name));
    return _remoteOrder!;
  }

  CatalogSubmitResult _submitResult(
    DraftOrder order, {
    bool updated = false,
    List<OrderLine>? addedLines,
  }) {
    final uri = OrderShare.catalogWhatsAppUri(
      order,
      _company?.phone,
      updated: updated,
      addedLines: addedLines,
    );
    return CatalogSubmitResult(
      order: order,
      whatsappUri: uri,
      missingPhone: uri == null,
      updated: updated,
    );
  }

  Future<void> _setOpenOrder(CatalogOpenOrder? order) async {
    final orderIdChanged = _openOrder?.orderId != order?.orderId;
    _openOrder = order;
    await _cart.saveOpenOrder(companyId, order);
    if (order == null) {
      await _orderSub?.cancel();
      _orderSub = null;
      return;
    }
    if (orderIdChanged || _orderSub == null) {
      _bindOpenOrder();
    }
  }

  Future<void> _start() async {
    await _hydrateLocal();
    _bindOpenOrder();
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
      final loaded = _cart.load(companyId);
      _openOrder = _cart.loadOpenOrder(companyId);
      if (_openOrder != null &&
          loaded.isNotEmpty &&
          loaded.every((line) => !line.requested)) {
        _legacyOpenCart = true;
        _requestedCache = [
          for (final line in loaded) line.copyWith(requested: true),
        ];
        _pending = const [];
      } else {
        _pending = [
          for (final line in loaded)
            if (!line.requested) line,
        ];
        _requestedCache = [
          for (final line in loaded)
            if (line.requested) line,
        ];
      }
      _company = _local?.loadCompany(companyId);
      if (_company != null ||
          _pending.isNotEmpty ||
          _requestedCache.isNotEmpty ||
          _openOrder != null) {
        notifyListeners();
      }
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

  void _bindOpenOrder() {
    unawaited(_orderSub?.cancel());
    _orderSub = null;
    final open = _openOrder;
    if (open == null) return;
    _orderSub = _orders
        .watchOrder(companyId, open.orderId)
        .listen(
          _onRemoteOrder,
          onError: (Object error, StackTrace stack) {
            debugPrint('Catalog order watch failed: $error');
            debugPrint('$stack');
            unawaited(_releaseClosedOrder());
          },
        );
  }

  void _onRemoteOrder(DraftOrder? order) {
    if (!_alive) return;
    if (order == null ||
        !order.isCatalog ||
        !order.isActive ||
        order.isDeleted) {
      unawaited(_releaseClosedOrder());
      return;
    }
    if (_legacyOpenCart) {
      _pending = _extrasAgainst(order.lines, [..._requestedCache, ..._pending]);
      _legacyOpenCart = false;
    }
    _remoteOrder = order;
    _requestedCache = _cartLinesFrom(order.lines, requested: true);
    _persistCart();
    if (_alive) notifyListeners();
  }

  Future<void> _releaseClosedOrder() async {
    if (!_alive) return;
    if (_openOrder == null &&
        _pending.isEmpty &&
        _requestedCache.isEmpty &&
        _remoteOrder == null) {
      return;
    }
    _pending = const [];
    _requestedCache = const [];
    _remoteOrder = null;
    _legacyOpenCart = false;
    _openOrder = null;
    final sub = _orderSub;
    _orderSub = null;
    if (_alive) notifyListeners();
    await sub?.cancel();
    if (!_alive) return;
    await _cart.clear(companyId);
    await _cart.saveOpenOrder(companyId, null);
  }

  void _pruneMissing() {
    final next = [
      for (final line in _pending)
        if (productById(line.productId) != null) line,
    ];
    if (next.length != _pending.length) {
      _pending = next;
      _persistCart();
    }
  }

  void _setPending(List<CatalogCartLine> next, {bool persist = true}) {
    _pending = next;
    notifyListeners();
    if (persist) _persistCart();
  }

  void _persistCart() {
    unawaited(_cart.save(companyId, [..._pending, ..._requestedCache]));
  }

  int get _uniqueLineCount {
    return {
      for (final line in requestedCartLines) line.lineKey,
      for (final line in _pending) line.lineKey,
    }.length;
  }

  int _requestedQty(String lineKey) {
    for (final line in requestedCartLines) {
      if (line.lineKey == lineKey) return line.quantity;
    }
    return 0;
  }

  List<OrderLine> _resolvePending(List<CatalogCartLine> items) {
    final result = <OrderLine>[];
    for (final item in items) {
      final product = productById(item.productId);
      if (product == null || product.status != ProductStatus.activo) continue;
      final variant = product.variantFor(item.size, item.color);
      if (variant == null || variant.stock <= 0) continue;
      final room = variant.stock - _requestedQty(item.lineKey);
      if (room < 1) continue;
      final quantity = item.quantity.clamp(1, room).toInt();
      result.add(
        OrderLine(product: product, variant: variant, quantity: quantity),
      );
    }
    return OrderLine.sorted(result);
  }

  List<OrderLine> _resolveRequested(List<CatalogCartLine> items) {
    final result = <OrderLine>[];
    for (final item in items) {
      final product = productById(item.productId);
      if (product == null) continue;
      final variant = product.variantFor(item.size, item.color);
      if (variant == null) continue;
      result.add(
        OrderLine(
          product: product,
          variant: variant,
          quantity: item.quantity.clamp(1, 9999).toInt(),
        ),
      );
    }
    return OrderLine.sorted(result);
  }

  List<CatalogCartLine> _cartLinesFrom(
    Iterable<OrderLine> lines, {
    required bool requested,
  }) {
    return [
      for (final line in lines)
        CatalogCartLine(
          productId: line.product.id,
          size: line.variant.size,
          color: line.variant.color,
          quantity: line.quantity,
          requested: requested,
        ),
    ];
  }

  List<CatalogCartLine> _extrasAgainst(
    List<OrderLine> remote,
    List<CatalogCartLine> local,
  ) {
    final serverQty = <String, int>{};
    for (final line in remote) {
      serverQty[line.lineKey] = (serverQty[line.lineKey] ?? 0) + line.quantity;
    }
    final extras = <CatalogCartLine>[];
    for (final line in local) {
      final extra = line.quantity - (serverQty[line.lineKey] ?? 0);
      if (extra <= 0) continue;
      extras.add(line.copyWith(quantity: extra, requested: false));
      serverQty[line.lineKey] = line.quantity;
    }
    return extras;
  }

  @override
  void dispose() {
    _alive = false;
    _productSub?.cancel();
    _orderSub?.cancel();
    super.dispose();
  }
}
