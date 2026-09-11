import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/image_compress.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../widgets/product_image.dart';
import 'variant_editor.dart';

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, this.id});

  final String? id;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _brand;
  late final TextEditingController _price;
  late final VariantDraft _draft;
  ApparelCategory? _category;
  final List<String> _images = [];
  String? _error;
  late final String _productId;
  bool _uploading = false;

  bool get isEditing => widget.id != null;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final existing = widget.id == null ? null : store.productById(widget.id!);
    _name = TextEditingController(text: existing?.name ?? '');
    _sku = TextEditingController(text: existing?.sku ?? store.nextSku());
    _brand = TextEditingController(text: existing?.brand ?? '');
    _price = TextEditingController(
      text: existing == null ? '' : existing.price.toStringAsFixed(0),
    );
    _category = existing?.category;
    _draft = VariantDraft(
      sizes: existing?.sizes,
      colors: existing?.colors,
      variants: existing?.variants,
    );
    if (existing != null) {
      _images.addAll(existing.images);
    }
    _productId = existing?.id ?? store.nextProductId();
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _brand.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _addImage() async {
    final remaining = maxProductImages - _images.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podés cargar hasta 10 fotos.')),
      );
      return;
    }
    final files = await ImagePicker().pickMultiImage(
      requestFullMetadata: false,
    );
    if (!mounted || files.isEmpty) return;
    setState(() {
      _error = null;
      _uploading = true;
    });
    final store = context.read<AppStore>();
    try {
      for (final file in files.take(remaining)) {
        final bytes = await file.readAsBytes();
        final url = await store.uploadProductImage(
          productId: _productId,
          bytes: bytes,
        );
        if (!mounted) return;
        setState(() => _images.add(url));
      }
    } on ImageUploadException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo cargar la foto.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate() || _category == null) {
      setState(() => _error = 'Completá los campos obligatorios.');
      return;
    }
    if (_draft.variants.isEmpty) {
      setState(() => _error = 'Agregá al menos una variante talle × color.');
      return;
    }
    final store = context.read<AppStore>();
    final existing = widget.id == null ? null : store.productById(widget.id!);
    final now = DateTime.now().toUtc();
    final product = Product(
      id: _productId,
      name: _name.text.trim(),
      sku: _sku.text.trim(),
      category: _category!,
      brand: _brand.text.trim(),
      price: double.parse(_price.text.trim().replaceAll('.', '')),
      images: List.of(_images),
      variants: List.of(_draft.variants),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      deletedAt: existing?.deletedAt,
    );
    try {
      await store.upsertProduct(product);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo guardar la prenda.');
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing ? 'Prenda actualizada' : 'Prenda guardada en el catálogo',
        ),
      ),
    );
    context.go('/producto/${product.id}');
  }

  @override
  Widget build(BuildContext context) {
    final wide = AppBreakpoints.isWide(context);
    final title = isEditing ? 'Editar prenda' : 'Nueva prenda';

    return SafeArea(
      child: Column(
        children: [
          _Header(
            title: title,
            subtitle: wide && !isEditing
                ? 'Completá los datos de la nueva prenda y sumala al catálogo.'
                : null,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.stockLow),
                ),
              ),
            ),
          Expanded(
            child: Form(key: _form, child: wide ? _wideBody() : _mobileBody()),
          ),
        ],
      ),
    );
  }

  Widget _mobileBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _ImagesEditor(
          images: _images,
          uploading: _uploading,
          onAdd: _uploading ? null : _addImage,
          onRemove: (i) => setState(() => _images.removeAt(i)),
        ),
        const SizedBox(height: 20),
        ..._fields(),
        const SizedBox(height: 8),
        VariantEditor(
          draft: _draft,
          wide: false,
          baseSku: _sku.text.trim(),
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _uploading ? null : _save,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Guardar prenda'),
        ),
      ],
    );
  }

  Widget _wideBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ImagesEditor(
                images: _images,
                uploading: _uploading,
                onAdd: _uploading ? null : _addImage,
                onRemove: (i) => setState(() => _images.removeAt(i)),
                wide: true,
              ),
            ),
            const SizedBox(width: 32),
            Expanded(child: Column(children: [..._fields()])),
          ],
        ),
        const SizedBox(height: 24),
        VariantEditor(
          draft: _draft,
          wide: true,
          baseSku: _sku.text.trim(),
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 220,
            child: FilledButton.icon(
              onPressed: _uploading ? null : _save,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Guardar prenda'),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _fields() {
    return [
      _LabeledField(
        label: 'Nombre',
        required: true,
        icon: Icons.sell_outlined,
        child: TextFormField(
          controller: _name,
          decoration: const InputDecoration(hintText: 'Ej. Campera de cuero'),
          validator: _required,
        ),
      ),
      _LabeledField(
        label: 'SKU',
        required: true,
        icon: Icons.qr_code_2,
        child: TextFormField(
          controller: _sku,
          decoration: const InputDecoration(hintText: 'Ej. CJL-0255'),
          validator: _required,
        ),
      ),
      _LabeledField(
        label: 'Categoría',
        required: true,
        child: DropdownButtonFormField<ApparelCategory>(
          initialValue: _category,
          hint: const Text('Seleccioná una categoría'),
          items: [
            for (final category in ApparelCategory.values)
              DropdownMenuItem(value: category, child: Text(category.label)),
          ],
          onChanged: (v) => setState(() => _category = v),
          validator: (v) => v == null ? 'Elegí una categoría' : null,
        ),
      ),
      _LabeledField(
        label: 'Marca',
        required: true,
        icon: Icons.storefront_outlined,
        child: TextFormField(
          controller: _brand,
          decoration: const InputDecoration(hintText: 'Ej. Urban Threads'),
          validator: _required,
        ),
      ),
      _LabeledField(
        label: 'Precio',
        required: true,
        icon: Icons.attach_money,
        child: TextFormField(
          controller: _price,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Ej. 12500'),
          validator: _required,
        ),
      ),
    ];
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obligatorio';
    return null;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.icon,
    this.required = false,
  });

  final String label;
  final Widget child;
  final IconData? icon;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              children: [
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.terracotta),
                  ),
              ],
            ),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          icon == null
              ? child
              : Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    child,
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(icon, size: 18, color: AppColors.mutedText),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _ImagesEditor extends StatelessWidget {
  const _ImagesEditor({
    required this.images,
    required this.onRemove,
    this.onAdd,
    this.uploading = false,
    this.wide = false,
  });

  final List<String> images;
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemove;
  final bool uploading;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          wide ? 'Imágenes de la prenda' : 'Fotos de la prenda',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          wide
              ? 'Arrastrá o hacé clic para subir imágenes (máx. 10)'
              : 'Agregá o seleccioná imágenes (una o más)',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < images.length; i++)
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ProductImage(
                        path: images[i],
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => onRemove(i),
                        child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.close, size: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: Ink(
                width: wide ? double.infinity : 88,
                height: wide ? 120 : 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                    color: AppColors.terracotta.withValues(alpha: 0.45),
                    style: BorderStyle.solid,
                  ),
                  color: isDark
                      ? AppColors.terracotta.withValues(alpha: 0.08)
                      : AppColors.terracottaChip,
                ),
                child: uploading
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : wide
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.terracotta,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Agregar foto (una o más)',
                            style: TextStyle(color: AppColors.terracotta),
                          ),
                          Text(
                            'JPEG, PNG o WEBP hasta 10 MB.',
                            style: TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: AppColors.terracotta),
                          Text(
                            'Agregar',
                            style: TextStyle(
                              color: AppColors.terracotta,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
