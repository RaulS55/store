import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../widgets/product_image.dart';
import '../../widgets/stock_dot.dart';

class ProductTable extends StatelessWidget {
  const ProductTable({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ivaEnabled = context.watch<AppStore>().ivaEnabled;
    final headerStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppColors.mutedText,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.sizeOf(context).width - 280,
          ),
          child: DataTable(
            showCheckboxColumn: false,
            headingRowHeight: 48,
            dataRowMinHeight: 68,
            dataRowMaxHeight: 76,
            headingTextStyle: headerStyle,
            columns: const [
              DataColumn(label: Text('PRODUCTO')),
              DataColumn(label: Text('CATEGORÍA')),
              DataColumn(label: Text('PÚBLICO')),
              DataColumn(label: Text('TALLE')),
              DataColumn(label: Text('COLOR')),
              DataColumn(label: Text('MARCA')),
              DataColumn(label: Text('STOCK')),
              DataColumn(label: Text('PRECIO')),
              DataColumn(label: Text('ESTADO')),
            ],
            rows: [
              for (final product in products)
                DataRow(
                  onSelectChanged: (_) =>
                      context.push('/producto/${product.id}'),
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: ProductImage(
                              path: product.image,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'SKU: ${product.sku}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.mutedText),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        product.categoryLabel.isEmpty
                            ? '—'
                            : product.categoryLabel,
                      ),
                    ),
                    DataCell(
                      Text(
                        product.audienceLabel.isEmpty
                            ? '—'
                            : product.audienceLabel,
                      ),
                    ),
                    DataCell(Text(product.sizeLabel)),
                    DataCell(
                      Row(
                        children: [
                          for (final color in product.colors.take(4))
                            if (!color.isCustom)
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: color.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.lightBorder,
                                  ),
                                ),
                              ),
                          const SizedBox(width: 4),
                          Text(product.colorLabel),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(product.brand.trim().isEmpty ? '—' : product.brand),
                    ),
                    DataCell(
                      Text(
                        'Stock: ${product.stock}',
                        style: TextStyle(
                          color: product.isLowStock ? AppColors.stockLow : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            MoneyFormat.compact(product.price),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (ivaEnabled)
                            Text(
                              '+ IVA',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.mutedText),
                            ),
                        ],
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          StockDot(low: product.isLowStock),
                          const SizedBox(width: 6),
                          Text(
                            product.isLowStock ? 'Bajo stock' : 'Disponible',
                          ),
                        ],
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
}
