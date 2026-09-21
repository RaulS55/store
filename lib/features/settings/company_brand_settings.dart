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
import '../../widgets/product_image.dart';

class CompanyBrandSettings extends StatefulWidget {
  const CompanyBrandSettings({super.key, this.pickLogo = pickGalleryImages});

  final Future<List<PickedImageFile>> Function({required int limit}) pickLogo;

  @override
  State<CompanyBrandSettings> createState() => _CompanyBrandSettingsState();
}

class _CompanyBrandSettingsState extends State<CompanyBrandSettings> {
  late final TextEditingController _name;
  late final TextEditingController _instagram;
  late final TextEditingController _tiktok;
  late final TextEditingController _facebook;
  late String _savedName;
  String? _savedInstagram;
  String? _savedTiktok;
  String? _savedFacebook;
  Uint8List? _logoPreview;
  var _savingName = false;
  var _savingSocials = false;
  var _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    final company = context.read<SessionStore>().company;
    _savedName = company?.name ?? '';
    _savedInstagram = company?.instagram;
    _savedTiktok = company?.tiktok;
    _savedFacebook = company?.facebook;
    _name = TextEditingController(text: _savedName);
    _instagram = TextEditingController(text: _savedInstagram ?? '');
    _tiktok = TextEditingController(text: _savedTiktok ?? '');
    _facebook = TextEditingController(text: _savedFacebook ?? '');
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
      blankToNull(_instagram.text) != _savedInstagram ||
      blankToNull(_tiktok.text) != _savedTiktok ||
      blankToNull(_facebook.text) != _savedFacebook;

  Future<void> _showError(Object error) async {
    if (!mounted) return;
    debugPrint('Company brand save failed: $error');
    final message = error is SessionException
        ? error.message
        : error is ImageUploadException
        ? error.message
        : 'No se pudo guardar el perfil del negocio.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSaved() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Guardado exitosamente')));
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
        instagram: _instagram.text,
        tiktok: _tiktok.text,
        facebook: _facebook.text,
      );
      if (!mounted) return;
      final company = context.read<SessionStore>().company;
      _savedInstagram = company?.instagram;
      _savedTiktok = company?.tiktok;
      _savedFacebook = company?.facebook;
      _instagram.text = _savedInstagram ?? '';
      _tiktok.text = _savedTiktok ?? '';
      _facebook.text = _savedFacebook ?? '';
      _showSaved();
    } catch (error) {
      if (!mounted) return;
      _instagram.text = _savedInstagram ?? '';
      _tiktok.text = _savedTiktok ?? '';
      _facebook.text = _savedFacebook ?? '';
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
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('company-instagram'),
                controller: _instagram,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Instagram',
                  hintText: '@tunegocio',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('company-tiktok'),
                controller: _tiktok,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'TikTok',
                  hintText: '@tunegocio',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('company-facebook'),
                controller: _facebook,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Facebook',
                  hintText: 'facebook.com/tunegocio',
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => unawaited(_saveSocials()),
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
