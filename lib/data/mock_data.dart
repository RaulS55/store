import '../models/customer.dart';

class MockCatalog {
  static List<Customer> customers() {
    return const [
      Customer(
        id: 'c1',
        name: 'Mónica Fernández',
        cuit: '27-21543678-3',
        taxCondition: TaxCondition.responsableInscripto,
        phone: '+54 9 11 4555-0101',
      ),
      Customer(
        id: 'c2',
        name: 'Boutique Abril',
        cuit: '30-71234567-9',
        taxCondition: TaxCondition.responsableInscripto,
        phone: '+54 9 11 4788-2200',
      ),
      Customer(
        id: 'c3',
        name: 'Distribuidora del Sur S.A.',
        cuit: '30-67894567-2',
        taxCondition: TaxCondition.responsableInscripto,
        phone: '+54 9 11 4300-8899',
        address: 'Av. Rivadavia 1234, CABA',
      ),
      Customer(
        id: 'c4',
        name: 'Ana García',
        cuit: '27-33445566-1',
        taxCondition: TaxCondition.monotributo,
        phone: '+54 9 11 5123-4477',
        address: 'Local 12, Palermo',
      ),
    ];
  }
}
