import '../models/lot.dart';

abstract class LotAccess {
  String nextLotId(String companyId);

  Stream<List<Lot>> watchLots(String companyId);

  Future<void> saveLot(String companyId, Lot lot);
}
