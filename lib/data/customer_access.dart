import '../models/customer.dart';

abstract class CustomerAccess {
  String nextCustomerId(String companyId);

  Stream<List<Customer>> watchCustomers(String companyId);

  Future<void> saveCustomer(String companyId, Customer customer);
}
