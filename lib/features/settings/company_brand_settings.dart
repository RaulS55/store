import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/gallery_picker.dart';
import '../../data/image_compress.dart';
import '../../data/picked_image_file.dart';
import '../../data/session_exception.dart';
import '../../data/session_store.dart';
import '../../models/company.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/product_image.dart';

class CompanyBrandSettings extends StatefulWidget {
  const CompanyBrandSettings({super.key, this.pickLogo = pickGalleryImages});

  final Future<List<PickedImageFile>> Function({required int limit}) pickLogo;

  @override
  State<CompanyBrandSettings> createState() => _CompanyBrandSettingsState();
}

class _CompanyBrandSettingsState extends State<CompanyBrandSettings> {
  late final TextEditingController _name;
  late final _SocialDraft _instagram;
  late final _SocialDraft _tiktok;
  late final _SocialDraft _facebook;
  late String _savedName;
  Uint8List? _logoPreview;
  var _savingName = false;
  var _savingSocials = false;
  var _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    final company = context.read<SessionStore>().company;
    _savedName = company?.name ?? '';
    _name = TextEditingController(text: _savedName);
    _instagram = _SocialDraft(company?.instagram ?? const []);
    _tiktok = _SocialDraft(company?.tiktok ?? const []);
    _facebook = _SocialDraft(company?.facebook ?? const []);
  }

  @override
  void dispose() {
    _name.dispose();
    _instagram.dispose();
    _tiktok.dispose();
    _facebook.dispose();
    super.dispose();
  }

  bool get _nameDirty => _name.text.trim() != _savedName;

  bool get _socialsDirty =>
      _instagram.dirty || _tiktok.dirty || _facebook.dirty;

  Future<void> _showError(Object error) async {
    if (!mounted) return;
    debugPrint('Company brand save failed: $error');
    final message = error is SessionException
        ? error.message
        : error is ImageUploadException
        ? error.message
        : 'No se pudo guardar el perfil del negocio.';
    AppSnackBar.show(context, content: Text(message));
  }

  void _showSaved() {
    if (!mounted) return;
    AppSnackBar.show(context, content: Text('Guardado exitosamente'));
  }

  Future<void> _saveName() async {
    if (_savingName) return;
    final next = _name.text.trim();
    if (next == _savedName) {
      _name.text = _savedName;
      return;
    }
    setState(() => _savingName = true);
    try {
      await context.read<SessionStore>().setCompanyName(next);
      if (!mounted) return;
      _savedName = context.read<SessionStore>().company?.name ?? next;
      _name.text = _savedName;
      _showSaved();
    } catch (error) {
      if (!mounted) return;
      _name.text = _savedName;
      await _showError(error);
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _saveSocials() async {
    if (_savingSocials) return;
    setState(() => _savingSocials = true);
    try {
      await context.read<SessionStore>().setCompanySocials(
        instagram: _instagram.draft,
        tiktok: _tiktok.draft,
        facebook: _facebook.draft,
      );
      if (!mounted) return;
      final company = context.read<SessionStore>().company;
      setState(() {
        _instagram.commit(company?.instagram ?? const []);
        _tiktok.commit(company?.tiktok ?? const []);
        _facebook.commit(company?.facebook ?? const []);
      });
      _showSaved();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _instagram.reset();
        _tiktok.reset();
        _facebook.reset();
      });
      await _showError(error);
    } finally {
      if (mounted) setState(() => _savingSocials = false);
    }
  }

  Future<void> _pickLogo() async {
    if (_uploadingLogo) return;
    final files = await widget.pickLogo(limit: 1);
    if (!mounted || files.isEmpty) return;
    final file = files.first;
    setState(() {
      _logoPreview = file.bytes;
      _uploadingLogo = true;
    });
    try {
      final store = context.read<AppStore>();
      final compressed = await store.prepareProductImage(file.bytes);
      if (!mounted) return;
      setState(() => _logoPreview = compressed.bytes);
      final url = await store.uploadCompanyLogo(bytes: compressed.bytes);
      await context.read<SessionStore>().setCompanyLogo(url);
      if (!mounted) return;
      _showSaved();
    } catch (error) {
      if (!mounted) return;
      setState(() => _logoPreview = null);
      await _showError(error);
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _removeLogo() async {
    if (_uploadingLogo) return;
    setState(() => _uploadingLogo = true);
    try {
      await context.read<AppStore>().deleteCompanyLogo();
      await context.read<SessionStore>().setCompanyLogo(null);
      if (!mounted) return;
      setState(() => _logoPreview = null);
      _showSaved();
    } catch (error) {
      await _showError(error);
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<SessionStore>().company;
    final logoUrl = company?.logoUrl ?? '';
    final canSaveName =
        _nameDirty && !_savingName && _name.text.trim().isNotEmpty;
    final canSaveSocials = _socialsDirty && !_savingSocials;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(
          title: Text('Tu negocio'),
          subtitle: Text(
            'Nombre, logo y redes sociales. Solo el creador puede cambiarlos.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LogoButton(
                    url: logoUrl,
                    bytes: _logoPreview,
                    uploading: _uploadingLogo,
                    onPick: () => unawaited(_pickLogo()),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: const ValueKey('company-name'),
                          controller: _name,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                          maxLength: maxCompanyNameLength,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la empresa',
                            counterText: '',
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => unawaited(_saveName()),
                        ),
                        if (logoUrl.isNotEmpty || _logoPreview != null)
                          TextButton(
                            key: const ValueKey('remove-company-logo'),
                            onPressed: _uploadingLogo
                                ? null
                                : () => unawaited(_removeLogo()),
                            child: const Text('Quitar logo'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const ValueKey('save-company-name'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: canSaveName ? () => unawaited(_saveName()) : null,
                  child: Text(_savingName ? 'Guardando…' : 'Guardar nombre'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Redes sociales',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Podés cargar más de una cuenta en cada red.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 8),
              _SocialAccountFields(
                id: 'instagram',
                label: 'Instagram',
                hint: '@tunegocio',
                draft: _instagram,
                onChanged: () => setState(() {}),
              ),
              _SocialAccountFields(
                id: 'tiktok',
                label: 'TikTok',
                hint: '@tunegocio',
                draft: _tiktok,
                onChanged: () => setState(() {}),
              ),
              _SocialAccountFields(
                id: 'facebook',
                label: 'Facebook',
                hint: 'facebook.com/tunegocio',
                draft: _facebook,
                onChanged: () => setState(() {}),
                onSubmitted: () => unawaited(_saveSocials()),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const ValueKey('save-company-socials'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: canSaveSocials
                      ? () => unawaited(_saveSocials())
                      : null,
                  child: Text(_savingSocials ? 'Guardando…' : 'Guardar redes'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SocialDraft {
  _SocialDraft(List<String> saved) : _saved = List<String>.from(saved) {
    _syncControllers(_saved);
  }

  List<String> _saved;
  final List<TextEditingController> controllers = [];

  List<String> get draft => [
    for (final controller in controllers)
      if (blankToNull(controller.text) != null) blankToNull(controller.text)!,
  ];

  bool get dirty => !listEquals(draft, _saved);

  bool get canAdd =>
      controllers.length < maxCompanySocialAccounts &&
      blankToNull(controllers.last.text) != null;

  void add() {
    if (!canAdd) return;
    controllers.add(TextEditingController());
  }

  void remove(int index) {
    if (controllers.length == 1) {
      controllers.first.clear();
      return;
    }
    controllers.removeAt(index).dispose();
  }

  void commit(List<String> saved) {
    _saved = List<String>.from(saved);
    _syncControllers(_saved);
  }

  void reset() => _syncControllers(_saved);

  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  void _syncControllers(List<String> values) {
    final texts = values.isEmpty ? const [''] : values;
    while (controllers.length > texts.length) {
      controllers.removeLast().dispose();
    }
    for (var index = 0; index < texts.length; index++) {
      if (index < controllers.length) {
        controllers[index].text = texts[index];
      } else {
        controllers.add(TextEditingController(text: texts[index]));
      }
    }
  }
}

class _SocialAccountFields extends StatelessWidget {
  const _SocialAccountFields({
    required this.id,
    required this.label,
    required this.hint,
    required this.draft,
    required this.onChanged,
    this.onSubmitted,
  });

  final String id;
  final String label;
  final String hint;
  final _SocialDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final count = draft.controllers.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < count; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey(
                    index == 0 ? 'company-$id' : 'company-$id-$index',
                  ),
                  controller: draft.controllers[index],
                  keyboardType: TextInputType.url,
                  textInputAction: onSubmitted == null || index < count - 1
                      ? TextInputAction.next
                      : TextInputAction.done,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: count == 1 ? label : '$label ${index + 1}',
                    hintText: hint,
                  ),
                  onChanged: (_) => onChanged(),
                  onSubmitted: onSubmitted == null || index < count - 1
                      ? null
                      : (_) => onSubmitted!(),
                ),
              ),
              if (count > 1)
                IconButton(
                  key: ValueKey('remove-company-$id-$index'),
                  tooltip: 'Quitar cuenta',
                  onPressed: () {
                    draft.remove(index);
                    onChanged();
                  },
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ],
        if (count < maxCompanySocialAccounts)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: ValueKey('add-company-$id'),
              onPressed: draft.canAdd
                  ? () {
                      draft.add();
                      onChanged();
                    }
                  : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar otra cuenta'),
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _LogoButton extends StatelessWidget {
  const _LogoButton({
    required this.url,
    required this.bytes,
    required this.uploading,
    required this.onPick,
  });

  final String url;
  final Uint8List? bytes;
  final bool uploading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppRadii.md);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('pick-company-logo'),
        onTap: uploading ? null : onPick,
        borderRadius: radius,
        child: Ink(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            borderRadius: radius,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: radius,
                child: bytes != null && bytes!.isNotEmpty
                    ? Image.memory(bytes!, fit: BoxFit.cover)
                    : url.isNotEmpty
                    ? ProductImage(path: url, borderRadius: radius)
                    : Icon(
                        Icons.storefront_outlined,
                        color: isDark ? Colors.white38 : AppColors.mutedText,
                      ),
              ),
              ColoredBox(
                color: Colors.black.withValues(alpha: uploading ? 0.45 : 0.18),
                child: Center(
                  child: uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.photo_camera_outlined,
                          color: Colors.white,
                          size: 20,
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
