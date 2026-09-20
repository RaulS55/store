import 'dart:async';

import 'package:store_app/data/lot_access.dart';
import 'package:store_app/models/lot.dart';

class FakeLotAccess implements LotAccess {
  final lots = <String, Map<String, Lot>>{};
  final _controllers = <String, StreamController<List<Lot>>>{};
  var _seq = 0;

  String _id() => 'l-fake-${++_seq}';

  StreamController<List<Lot>> _controller(String companyId) {
    return _controllers.putIfAbsent(
      companyId,
      StreamController<List<Lot>>.broadcast,
    );
  }

  List<Lot> _list(String companyId) {
    final list = [...?lots[companyId]?.values];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  String nextLotId(String companyId) => _id();

  @override
  Stream<List<Lot>> watchLots(String companyId) async* {
    yield _list(companyId);
    yield* _controller(companyId).stream;
  }

  @override
  Future<void> saveLot(String companyId, Lot lot) async {
    lots.putIfAbsent(companyId, () => {})[lot.id] = lot;
    _controller(companyId).add(_list(companyId));
  }
}
