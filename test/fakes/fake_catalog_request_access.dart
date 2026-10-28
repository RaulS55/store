import 'dart:async';

import 'package:store_app/data/catalog_request_access.dart';
import 'package:store_app/models/catalog_request.dart';

class FakeCatalogRequestAccess implements CatalogRequestAccess {
  final requests = <String, Map<String, CatalogRequest>>{};
  final _controllers = <String, StreamController<List<CatalogRequest>>>{};
  final _listeners = <String, Set<MultiStreamController<CatalogRequest?>>>{};
  var _seq = 0;

  String _id() => 'r-fake-${++_seq}';

  String _key(String companyId, String requestId) => '$companyId::$requestId';

  StreamController<List<CatalogRequest>> _controller(String companyId) {
    return _controllers.putIfAbsent(
      companyId,
      StreamController<List<CatalogRequest>>.broadcast,
    );
  }

  CatalogRequest? _doc(String companyId, String requestId) {
    final request = requests[companyId]?[requestId];
    if (request == null || request.isDeleted) return null;
    return request;
  }

  List<CatalogRequest> _list(String companyId) {
    final list = [
      for (final request in [...?requests[companyId]?.values])
        if (!request.isDeleted) request,
    ];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  void _emit(String companyId, String requestId) {
    final request = _doc(companyId, requestId);
    for (final listener in [...?_listeners[_key(companyId, requestId)]]) {
      listener.add(request);
    }
    _controller(companyId).add(_list(companyId));
  }

  @override
  String nextRequestId(String companyId) => _id();

  @override
  Stream<List<CatalogRequest>> watchRequests(String companyId) async* {
    yield _list(companyId);
    yield* _controller(companyId).stream;
  }

  @override
  Stream<CatalogRequest?> watchRequest(String companyId, String requestId) {
    final key = _key(companyId, requestId);
    return Stream<CatalogRequest?>.multi((listener) {
      _listeners.putIfAbsent(key, () => {}).add(listener);
      listener
        ..add(_doc(companyId, requestId))
        ..onCancel = () {
          _listeners[key]?.remove(listener);
        };
    }, isBroadcast: true);
  }

  @override
  Future<CatalogRequest?> readRequest(
    String companyId,
    String requestId,
  ) async {
    return _doc(companyId, requestId);
  }

  @override
  Future<void> saveRequest(String companyId, CatalogRequest request) async {
    final previous = requests[companyId]?[request.id];
    if (previous != null && previous.status != request.status) {
      throw StateError('status changes must use updateRequest');
    }
    requests.putIfAbsent(companyId, () => {})[request.id] = request;
    _emit(companyId, request.id);
  }

  @override
  Future<void> updateRequest(
    String companyId,
    String requestId,
    Map<String, Object?> data,
  ) async {
    final current = requests[companyId]?[requestId];
    if (current == null) {
      throw StateError('Missing catalog request $requestId');
    }
    requests[companyId]![requestId] = current.copyWith(
      status: data.containsKey('status')
          ? CatalogRequestStatus.fromStorage(data['status'] as String?)
          : null,
      orderId: data['orderId'] as String?,
      orderNumber: data['orderNumber'] as String?,
      customerId: data['customerId'] as String?,
      updatedAt: _stamp(data['updatedAt']),
      resolvedAt: _stamp(data['resolvedAt']),
    );
    _emit(companyId, requestId);
  }
}

DateTime? _stamp(Object? value) {
  if (value is DateTime) return value.toUtc();
  if (value is String && value.isNotEmpty) return DateTime.parse(value).toUtc();
  return null;
}
