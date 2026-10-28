import 'map_date.dart';
import 'map_value.dart';
import 'order.dart';
import 'sync_record.dart';

enum CatalogRequestStatus {
  pendiente,
  aprobado,
  rechazado;

  static CatalogRequestStatus fromStorage(String? value) {
    for (final status in CatalogRequestStatus.values) {
      if (status.name == value) return status;
    }
    throw FormatException('Unknown catalog request status: $value');
  }
}

enum CatalogRequestKind {
  nuevo,
  agregado;

  static CatalogRequestKind fromStorage(String? value) {
    for (final kind in CatalogRequestKind.values) {
      if (kind.name == value) return kind;
    }
    throw FormatException('Unknown catalog request kind: $value');
  }
}

class CatalogRequest {
  CatalogRequest({
    required this.id,
    required this.customerName,
    this.customerPhone,
    List<OrderLine>? lines,
    this.status = CatalogRequestStatus.pendiente,
    this.kind = CatalogRequestKind.nuevo,
    this.targetOrderId,
    this.targetOrderNumber,
    this.orderId,
    this.orderNumber,
    this.customerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.resolvedAt,
    this.deletedAt,
  }) : lines = lines ?? <OrderLine>[],
       createdAt = createdAt ?? DateTime.now().toUtc(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now().toUtc();

  final String id;
  final String customerName;
  final String? customerPhone;
  final List<OrderLine> lines;
  CatalogRequestStatus status;
  final CatalogRequestKind kind;
  final String? targetOrderId;
  final String? targetOrderNumber;
  final String? orderId;
  final String? orderNumber;
  final String? customerId;
  final DateTime createdAt;
  DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  bool get isPending => status == CatalogRequestStatus.pendiente && !isDeleted;

  bool get isApproved => status == CatalogRequestStatus.aprobado;

  bool get isRejected => status == CatalogRequestStatus.rechazado;

  bool get isAddition => kind == CatalogRequestKind.agregado;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  double get total => lines.fold(0, (sum, line) => sum + line.lineTotal);

  String get initials {
    final trimmed = customerName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  CatalogRequest copyWith({
    String? customerName,
    String? customerPhone,
    List<OrderLine>? lines,
    CatalogRequestStatus? status,
    String? targetOrderId,
    String? targetOrderNumber,
    String? orderId,
    String? orderNumber,
    String? customerId,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    DateTime? deletedAt,
  }) {
    return CatalogRequest(
      id: id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      lines: lines ?? this.lines,
      status: status ?? this.status,
      kind: kind,
      targetOrderId: targetOrderId ?? this.targetOrderId,
      targetOrderNumber: targetOrderNumber ?? this.targetOrderNumber,
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  factory CatalogRequest.fromMap(String id, Map<String, dynamic> map) {
    final data = coerceStringKeyMap(map);
    final record = SyncRecord.fromMap(id, data);
    final rawLines = data['lines'] as List<dynamic>? ?? const [];
    return CatalogRequest(
      id: record.id,
      customerName: (data['customerName'] as String? ?? '').trim(),
      customerPhone: _blank(data['customerPhone']),
      lines: [
        for (final line in rawLines)
          if (line is Map) OrderLine.fromMap(coerceStringKeyMap(line)),
      ],
      status: CatalogRequestStatus.fromStorage(data['status'] as String?),
      kind: CatalogRequestKind.fromStorage(data['kind'] as String?),
      targetOrderId: _blank(data['targetOrderId']),
      targetOrderNumber: _blank(data['targetOrderNumber']),
      orderId: _blank(data['orderId']),
      orderNumber: _blank(data['orderNumber']),
      customerId: _blank(data['customerId']),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      resolvedAt: parseOptionalMapDate(data['resolvedAt']),
      deletedAt: record.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...SyncRecord(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      ).toMap(),
      'customerName': customerName.trim(),
      'customerPhone': customerPhone?.trim(),
      'lines': [for (final line in lines) line.toMap()],
      'status': status.name,
      'kind': kind.name,
      'targetOrderId': targetOrderId,
      'targetOrderNumber': targetOrderNumber,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'customerId': customerId,
      'resolvedAt': resolvedAt?.toUtc().toIso8601String(),
    };
  }
}

String? _blank(Object? value) {
  final text = (value as String?)?.trim() ?? '';
  if (text.isEmpty) return null;
  return text;
}
