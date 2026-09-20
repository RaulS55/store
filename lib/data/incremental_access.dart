import '../models/customer.dart';
import '../models/lot.dart';
import '../models/order.dart';
import '../models/product.dart';
import 'customer_access.dart';
import 'lot_access.dart';
import 'order_access.dart';
import 'product_access.dart';

abstract class IncrementalProductAccess implements ProductAccess {
  Future<List<Product>> fetchChanged(String companyId, DateTime? since);

  Stream<List<Product>> watchChanged(String companyId, DateTime since);
}

abstract class IncrementalCustomerAccess implements CustomerAccess {
  Future<List<Customer>> fetchChanged(String companyId, DateTime? since);

  Stream<List<Customer>> watchChanged(String companyId, DateTime since);
}

abstract class IncrementalOrderAccess implements OrderAccess {
  Future<List<DraftOrder>> fetchChanged(String companyId, DateTime? since);

  Stream<List<DraftOrder>> watchChanged(String companyId, DateTime since);
}

abstract class IncrementalLotAccess implements LotAccess {
  Future<List<Lot>> fetchChanged(String companyId, DateTime? since);

  Stream<List<Lot>> watchChanged(String companyId, DateTime since);
}
