import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/order.dart';
import 'download_file.dart';
import 'formatters.dart';
import 'invoice_document.dart';

const _terracotta = PdfColor.fromInt(0xFFC45C3E);
const _muted = PdfColor.fromInt(0xFF8A8F98);
const _charcoal = PdfColor.fromInt(0xFF1E1E1E);
const _border = PdfColor.fromInt(0xFFE6E8EA);

Future<Uint8List> buildInvoicePdf(
  DraftOrder order, {
  bool? includeProductCode,
}) async {
  final showCode = includeProductCode ?? order.includeProductCodeInInvoice;
  final customer = order.customer;
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
      build: (context) {
        return [
          pw.Center(child: _receiptIcon()),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              InvoiceDocument.brand,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2,
                color: _charcoal,
              ),
            ),
          ),
          pw.Center(
            child: pw.Text(
              InvoiceDocument.subtitle,
              style: const pw.TextStyle(
                fontSize: 9,
                letterSpacing: 0.8,
                color: _muted,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          _kv('Pedido #', order.orderNumber),
          _kv('Cliente', customer.name),
          _kv('WhatsApp', InvoiceDocument.phone(customer)),
          _kv('Fecha', InvoiceDocument.issuedAtLabel(order)),
          if (InvoiceDocument.cuit(customer) case final cuit?)
            _kv('CUIT', cuit),
          if (InvoiceDocument.condition(customer) case final condition?)
            _kv('Condición', condition),
          pw.SizedBox(height: 8),
          pw.Divider(color: _border, thickness: 1),
          pw.SizedBox(height: 8),
          _tableHeader(),
          pw.SizedBox(height: 8),
          for (final line in order.sortedLines) ...[
            _lineRow(line, includeProductCode: showCode),
            pw.SizedBox(height: 10),
          ],
          pw.Divider(color: _border, thickness: 1),
          pw.SizedBox(height: 6),
          if (order.ivaEnabled) ...[
            _kv('Subtotal', MoneyFormat.detailed(order.subtotal)),
            _kv(order.ivaLabel, MoneyFormat.detailed(order.iva)),
          ],
          _kv(
            'Total a facturar',
            MoneyFormat.detailed(order.total),
            emphasize: true,
          ),
          if (order.hasSena) ...[
            _kv('Seña', MoneyFormat.detailed(order.sena ?? 0)),
            _kv('Restante', MoneyFormat.detailed(order.remaining)),
          ],
        ];
      },
    ),
  );

  return doc.save();
}

Future<bool> downloadInvoicePdf(
  DraftOrder order, {
  bool? includeProductCode,
}) async {
  if (order.lines.isEmpty) return false;
  final bytes = await buildInvoicePdf(
    order,
    includeProductCode: includeProductCode,
  );
  if (bytes.isEmpty) return false;
  return downloadBytes(
    bytes: bytes,
    filename: InvoiceDocument.filename(order),
    mimeType: 'application/pdf',
  );
}

Future<bool> shareInvoicePdf(
  DraftOrder order, {
  bool? includeProductCode,
  Rect? sharePositionOrigin,
  Future<bool> Function({
    required Uint8List bytes,
    required String filename,
    String mimeType,
    Rect? sharePositionOrigin,
  })?
  shareBytes,
}) async {
  if (order.lines.isEmpty) return false;
  final bytes = await buildInvoicePdf(
    order,
    includeProductCode: includeProductCode,
  );
  if (bytes.isEmpty) return false;
  return (shareBytes ?? sharePdfBytes)(
    bytes: bytes,
    filename: InvoiceDocument.filename(order),
    mimeType: 'application/pdf',
    sharePositionOrigin: sharePositionOrigin,
  );
}

Future<bool> sharePdfBytes({
  required Uint8List bytes,
  required String filename,
  String mimeType = 'application/pdf',
  Rect? sharePositionOrigin,
}) async {
  if (bytes.isEmpty || filename.isEmpty) return false;
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType, name: filename)],
        fileNameOverrides: [filename],
        title: filename,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    return true;
  } catch (_) {
    return downloadBytes(bytes: bytes, filename: filename, mimeType: mimeType);
  }
}

pw.Widget _receiptIcon() {
  return pw.Container(
    width: 22,
    height: 26,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _terracotta, width: 1.5),
      borderRadius: pw.BorderRadius.circular(3),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        pw.Container(height: 1.3, color: _terracotta),
        pw.Container(height: 1.3, color: _terracotta),
        pw.Container(height: 1.3, color: _terracotta),
      ],
    ),
  );
}

pw.Widget _tableHeader() {
  return pw.Row(
    children: [
      pw.Expanded(flex: 4, child: _th('ÍTEM')),
      pw.Expanded(child: _th('CANT.', align: pw.TextAlign.center)),
      pw.Expanded(flex: 2, child: _th('P. UNIT.', align: pw.TextAlign.right)),
      pw.Expanded(flex: 2, child: _th('TOTAL', align: pw.TextAlign.right)),
    ],
  );
}

pw.Widget _lineRow(OrderLine line, {required bool includeProductCode}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 4,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              InvoiceDocument.lineTitle(
                line,
                includeProductCode: includeProductCode,
              ),
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: _charcoal,
              ),
            ),
            pw.Text(
              InvoiceDocument.lineDetail(line),
              style: const pw.TextStyle(fontSize: 8.5, color: _muted),
            ),
          ],
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          '${line.quantity}',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 9.5, color: _charcoal),
        ),
      ),
      pw.Expanded(
        flex: 2,
        child: pw.Text(
          MoneyFormat.detailed(line.unitPrice),
          textAlign: pw.TextAlign.right,
          style: const pw.TextStyle(fontSize: 9.5, color: _charcoal),
        ),
      ),
      pw.Expanded(
        flex: 2,
        child: pw.Text(
          MoneyFormat.detailed(line.lineTotal),
          textAlign: pw.TextAlign.right,
          style: const pw.TextStyle(fontSize: 9.5, color: _charcoal),
        ),
      ),
    ],
  );
}

pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) {
  return pw.Text(
    text,
    textAlign: align,
    style: pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      color: _muted,
    ),
  );
}

pw.Widget _kv(String label, String value, {bool emphasize = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: _charcoal),
        ),
        pw.Spacer(),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: emphasize ? _terracotta : _charcoal,
          ),
        ),
      ],
    ),
  );
}
