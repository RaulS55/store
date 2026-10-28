import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../data/session_exception.dart';
import '../../models/catalog_request.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_snack_bar.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _resolvedPageSize = 12;

  final _scroll = ScrollController();
  var _resolvedLimit = _resolvedPageSize;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels < position.maxScrollExtent - 280) return;
    _showMoreResolved();
  }

  void _showMoreResolved() {
    final resolved = context
        .read<AppStore>()
        .catalogRequests
        .where((request) => !request.isPending)
        .length;
    if (_resolvedLimit >= resolved) return;
    setState(() {
      _resolvedLimit = math.min(_resolvedLimit + _resolvedPageSize, resolved);
    });
  }

  void _scheduleFillCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent > 48) return;
      _showMoreResolved();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final visible = _visibleRequests(store.catalogRequests, _resolvedLimit);
    final shownResolved = visible.where((request) => !request.isPending).length;
    final wide = AppBreakpoints.isWide(context);
    _scheduleFillCheck();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              wide ? 24 : 20,
              wide ? 20 : 16,
              wide ? 24 : 20,
              8,
            ),
            child: Text(
              'Notificaciones',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(key: ValueKey('resolved-window-$shownResolved')),
          Expanded(
            child: visible.isEmpty
                ? const _EmptyNotifications()
                : ListView.builder(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(
                      wide ? 24 : 16,
                      8,
                      wide ? 24 : 16,
                      24,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final request = visible[index];
                      if (!request.isPending) {
                        return _ResolvedRequestCard(
                          key: ValueKey('notification-${request.id}'),
                          request: request,
                        );
                      }
                      return _RequestCard(
                        key: ValueKey('notification-${request.id}'),
                        request: request,
                        busy: store.isCatalogRequestBusy(request.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

DateTime _notificationTime(CatalogRequest request) {
  if (request.isPending) return request.createdAt;
  return request.resolvedAt ?? request.updatedAt;
}

List<CatalogRequest> _visibleRequests(
  List<CatalogRequest> requests,
  int resolvedLimit,
) {
  final pending = [
    for (final request in requests)
      if (request.isPending) request,
  ];
  final resolved = [
    for (final request in requests)
      if (!request.isPending) request,
  ]..sort((a, b) => _notificationTime(b).compareTo(_notificationTime(a)));
  final visible = [...pending, ...resolved.take(resolvedLimit)];
  visible.sort((a, b) => _notificationTime(b).compareTo(_notificationTime(a)));
  return visible;
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        key: const ValueKey('notifications-empty'),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none,
              color: AppColors.mutedText,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Todavía no hay pedidos del catálogo para aprobar.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Cuando un cliente envíe un pedido, aparece acá.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({super.key, required this.request, required this.busy});

  final CatalogRequest request;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitle = request.isAddition
        ? 'Suma prendas${_orderLabel(request)}'
        : 'Pedido nuevo del catálogo';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.terracottaChip,
                    child: Text(
                      request.initials,
                      style: const TextStyle(
                        color: AppColors.terracotta,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          catalogCustomerName(request.customerName),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if ((request.customerPhone ?? '').isNotEmpty)
                          Text(
                            request.customerPhone!,
                            key: ValueKey('request-phone-${request.id}'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.slate),
                          ),
                        Text(
                          '$subtitle · ${DateFormatters.short.format(request.createdAt.toLocal())}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.slate),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        MoneyFormat.detailed(request.total),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.terracotta,
                        ),
                      ),
                      Text(
                        request.itemCount == 1
                            ? '1 prenda'
                            : '${request.itemCount} prendas',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.slate,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _linesLabel(request),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: ValueKey('reject-request-${request.id}'),
                      onPressed: busy ? null : () => _reject(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: ValueKey('approve-request-${request.id}'),
                      onPressed: busy ? null : () => _approve(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        backgroundColor: AppColors.terracotta,
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Aprobar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context) async {
    final store = context.read<AppStore>();
    try {
      final order = await store.approveCatalogRequest(request.id);
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        content: Text('Se cargó el pedido ${order.orderNumber}.'),
      );
    } on SessionException catch (error) {
      if (!context.mounted) return;
      AppSnackBar.show(context, content: Text(error.message));
    } catch (_) {
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        content: const Text('No se pudo aprobar el pedido.'),
      );
    }
  }

  Future<void> _reject(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Rechazar solicitud',
      message:
          '¿Rechazar el pedido de ${catalogCustomerName(request.customerName)}? No se va a cargar en Pedidos.',
      confirmLabel: 'Sí, rechazar',
    );
    if (!confirmed || !context.mounted) return;
    final store = context.read<AppStore>();
    try {
      await store.rejectCatalogRequest(request.id);
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        content: Text(
          'Rechazaste la solicitud de ${catalogCustomerName(request.customerName)}.',
        ),
      );
    } on SessionException catch (error) {
      if (!context.mounted) return;
      AppSnackBar.show(context, content: Text(error.message));
    } catch (_) {
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        content: const Text('No se pudo rechazar la solicitud.'),
      );
    }
  }
}

class _ResolvedRequestCard extends StatelessWidget {
  const _ResolvedRequestCard({super.key, required this.request});

  final CatalogRequest request;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final approved = request.isApproved;
    final status = approved ? 'Aprobado' : 'Rechazado';
    final statusColor = approved ? AppColors.stockOk : AppColors.stockLow;
    final when = request.resolvedAt ?? request.updatedAt;
    final details = [
      DateFormatters.short.format(when.toLocal()),
      if ((request.orderNumber ?? '').isNotEmpty) request.orderNumber!,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.terracottaChip,
                child: Text(
                  request.initials,
                  style: const TextStyle(
                    color: AppColors.terracotta,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            catalogCustomerName(request.customerName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(
                          key: ValueKey('request-status-${request.id}'),
                          label: status,
                          color: statusColor,
                        ),
                      ],
                    ),
                    if ((request.customerPhone ?? '').isNotEmpty)
                      Text(
                        request.customerPhone!,
                        key: ValueKey('request-phone-${request.id}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                      ),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: ValueKey('request-detail-${request.id}'),
                onPressed: () => _showRequestDetail(context, request),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Ver detalle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Future<void> _showRequestDetail(BuildContext context, CatalogRequest request) {
  final store = context.read<AppStore>();
  final orderId = request.orderId;
  final order = orderId == null ? null : store.orderById(orderId);
  return showDialog<void>(
    context: context,
    builder: (context) {
      return _RequestDetailDialog(
        request: request,
        lines: order?.sortedLines ?? request.lines,
        total: order?.total ?? request.total,
        orderNumber: order?.orderNumber ?? request.orderNumber,
      );
    },
  );
}

class _RequestDetailDialog extends StatelessWidget {
  const _RequestDetailDialog({
    required this.request,
    required this.lines,
    required this.total,
    required this.orderNumber,
  });

  final CatalogRequest request;
  final List<OrderLine> lines;
  final double total;
  final String? orderNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final approved = request.isApproved;
    final status = approved ? 'Aprobado' : 'Rechazado';
    final statusColor = approved ? AppColors.stockOk : AppColors.stockLow;
    final when = request.resolvedAt ?? request.updatedAt;
    final number = orderNumber?.trim() ?? '';
    return Dialog(
      key: ValueKey('request-detail-dialog-${request.id}'),
      backgroundColor: AppColors.overlaySurface(isDark: isDark),
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Detalle del pedido',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusChip(label: status, color: statusColor),
                      const SizedBox(height: 14),
                      Text(
                        catalogCustomerName(request.customerName),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((request.customerPhone ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          request.customerPhone!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.slate,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        [
                          request.isAddition
                              ? 'Suma de prendas'
                              : 'Pedido nuevo',
                          if (number.isNotEmpty) number,
                          DateFormatters.invoice.format(when.toLocal()),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.slate,
                        ),
                      ),
                      if (!approved) ...[
                        const SizedBox(height: 8),
                        Text(
                          'No se cargó en Pedidos.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.slate,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Prendas',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final line in lines) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${line.quantity}× ${line.variantSku} · ${line.product.name} ${line.variant.size}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              MoneyFormat.detailed(line.lineTotal),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Total',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            MoneyFormat.detailed(total),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.terracotta,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Cerrar'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _orderLabel(CatalogRequest request) {
  final number = request.targetOrderNumber?.trim() ?? '';
  if (number.isEmpty) return '';
  return ' a $number';
}

String _linesLabel(CatalogRequest request) {
  final names = [
    for (final line in request.lines)
      '${line.quantity}× ${line.variantSku} · ${line.product.name} ${line.variant.size}',
  ];
  if (names.length <= 3) return names.join('\n');
  final extra = names.length - 3;
  return '${names.take(3).join('\n')}\ny $extra más';
}
