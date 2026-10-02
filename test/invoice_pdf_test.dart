import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/formatters.dart';
import 'package:store_app/data/invoice_document.dart';
import 'package:store_app/data/invoice_pdf.dart';
import 'package:store_app/models/order.dart';

import 'fakes/catalog_harness.dart';

void main() {
  final stamp = DateTime.utc(2026, 9, 11, 14, 30);
  final product = testProduct(createdAt: stamp, updatedAt: stamp);
  final customer = testCustomer(createdAt: stamp, updatedAt: stamp);

  DraftOrder order({bool iva = false, bool includeCode = true}) {
    return DraftOrder(
      id: 'o1',
      orderNumber: 'PED-1042',
      customer: customer,
      status: OrderStatus.cerrado,
      createdAt: stamp,
      updatedAt: stamp,
      closedAt: stamp,
      ivaEnabled: iva,
      ivaPercent: 21,
      includeProductCodeInInvoice: includeCode,
      lines: [
        OrderLine(
          product: product,
          variant: product.variants.first,
          quantity: 2,
        ),
      ],
    );
  }

  test('invoice document names the pdf from the order number', () {
    expect(InvoiceDocument.filename(order()), 'factura-PED-1042.pdf');
    expect(
      InvoiceDocument.filename(
        DraftOrder(id: 'o 2', orderNumber: 'PED/99', customer: customer),
      ),
      'factura-PED-99.pdf',
    );
  });

  test('invoice document formats lines like the on-screen factura', () {
    final line = order().lines.first;
    expect(
      InvoiceDocument.lineTitle(line, includeProductCode: true),
      'TST-0001 - REMERA TEST',
    );
    expect(
      InvoiceDocument.lineTitle(line, includeProductCode: false),
      'REMERA TEST',
    );
    expect(InvoiceDocument.lineDetail(line), 'Remeras · Talle M · Negro');
    expect(InvoiceDocument.phone(customer), '+54 9 11 4555-0101');
    expect(InvoiceDocument.cuit(customer), '27-21543678-3');
    expect(InvoiceDocument.condition(customer), 'Responsable Inscripto');
    expect(InvoiceDocument.cuit(testCustomer(cuit: null)), isNull);
    expect(InvoiceDocument.condition(testCustomer(taxCondition: null)), isNull);
    expect(
      InvoiceDocument.issuedAtLabel(order()),
      DateFormatters.invoice.format(stamp),
    );
  });

  test('invoice pdf contains the same summary drawn on screen', () async {
    final bytes = await buildInvoicePdf(order(iva: true));
    expect(bytes.take(5).toList(), '%PDF-'.codeUnits);
    final text = _pdfText(bytes);
    expect(text, contains('MODA'));
    expect(text, contains('STOCK'));
    expect(text, contains('RESUMEN'));
    expect(text, contains('FACTURA'));
    expect(text, contains('PED-1042'));
    expect(text, contains('Mónica'));
    expect(text, contains('Fernández'));
    expect(text, contains('TST-0001'));
    expect(text, contains('REMERA'));
    expect(text, contains('Remeras'));
    expect(text, contains('Talle'));
    expect(text, contains('CUIT'));
    expect(text, contains('Condición'));
    expect(text, contains('Subtotal'));
    expect(text, contains('IVA'));
    expect(text, contains('21%'));
    expect(text, contains('facturar'));
  });

  test('invoice pdf hides empty tax fields and subtotal without IVA', () async {
    final bytes = await buildInvoicePdf(
      DraftOrder(
        id: 'o2',
        orderNumber: 'PED-88',
        customer: testCustomer(
          createdAt: stamp,
          updatedAt: stamp,
          cuit: null,
          taxCondition: null,
        ),
        status: OrderStatus.cerrado,
        createdAt: stamp,
        updatedAt: stamp,
        closedAt: stamp,
        lines: [
          OrderLine(
            product: product,
            variant: product.variants.first,
            quantity: 1,
          ),
        ],
      ),
    );
    final text = _pdfText(bytes);
    expect(text, contains('PED-88'));
    expect(text, contains('facturar'));
    expect(text, isNot(contains('CUIT')));
    expect(text, isNot(contains('Condición')));
    expect(text, isNot(contains('Subtotal')));
    expect(text, isNot(contains('IVA')));
  });

  test('invoice pdf hides the product code when disabled', () async {
    final bytes = await buildInvoicePdf(order(), includeProductCode: false);
    final text = _pdfText(bytes);
    expect(text, contains('REMERA'));
    expect(text, isNot(contains('TST-0001')));
  });

  test('an open order can share the invoice pdf as it stands', () async {
    final open = DraftOrder(
      id: 'o-open',
      orderNumber: 'PED-77',
      customer: customer,
      createdAt: stamp,
      updatedAt: stamp,
      lines: [
        OrderLine(
          product: product,
          variant: product.variants.first,
          quantity: 1,
        ),
      ],
    );
    Uint8List? shared;
    String? name;
    final ok = await shareInvoicePdf(
      open,
      shareBytes:
          ({
            required bytes,
            required filename,
            mimeType = 'application/pdf',
            sharePositionOrigin,
          }) async {
            shared = bytes;
            name = filename;
            return true;
          },
    );
    expect(ok, isTrue);
    expect(name, 'factura-PED-77.pdf');
    expect(shared!.take(5).toList(), '%PDF-'.codeUnits);
    expect(_pdfText(shared!), contains('PED-77'));
  });

  test('an empty order cannot share an invoice pdf', () async {
    var shared = false;
    final ok = await shareInvoicePdf(
      DraftOrder(id: 'o-empty', orderNumber: 'PED-0', customer: customer),
      shareBytes:
          ({
            required bytes,
            required filename,
            mimeType = 'application/pdf',
            sharePositionOrigin,
          }) async {
            shared = true;
            return true;
          },
    );
    expect(ok, isFalse);
    expect(shared, isFalse);
  });
}

String _pdfText(Uint8List bytes) {
  final raw = latin1.decode(bytes, allowInvalid: true);
  final out = StringBuffer();
  var from = 0;
  while (true) {
    final startTag = raw.indexOf('stream', from);
    if (startTag < 0) break;
    var start = startTag + 6;
    if (start < raw.length && raw.codeUnitAt(start) == 13) start += 1;
    if (start < raw.length && raw.codeUnitAt(start) == 10) start += 1;
    final endTag = raw.indexOf('endstream', start);
    if (endTag < 0) break;
    var end = endTag;
    if (end > start && raw.codeUnitAt(end - 1) == 10) end -= 1;
    if (end > start && raw.codeUnitAt(end - 1) == 13) end -= 1;
    try {
      out.write(latin1.decode(zlib.decode(bytes.sublist(start, end))));
    } catch (_) {}
    from = endTag + 9;
  }
  return out.toString();
}
