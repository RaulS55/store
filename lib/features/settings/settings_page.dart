import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/clipboard_copy.dart';
import '../../data/formatters.dart';
import '../../data/gallery_picker.dart';
import '../../data/picked_image_file.dart';
import '../../data/session_exception.dart';
import '../../data/session_store.dart';
import '../../models/company.dart';
import '../../theme/tokens.dart';
import 'company_brand_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.pickLogo = pickGalleryImages});

  final Future<List<PickedImageFile>> Function({required int limit}) pickLogo;

  bool _isOwner(BuildContext context) {
    try {
      return context.watch<SessionStore>().isOwner;
    } on ProviderNotFoundException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Configuración',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (_isOwner(context)) ...[
              CompanyBrandSettings(pickLogo: pickLogo),
              const Divider(),
            ],
            SwitchListTile(
              value: store.themeMode == ThemeMode.dark,
              onChanged: (_) => store.toggleTheme(),
              title: const Text('Modo oscuro'),
              subtitle: const Text('Mismas superficies y acento terracota'),
              activeTrackColor: AppColors.terracotta,
            ),
            const Divider(),
            const _RubroSettings(),
            const Divider(),
            const _PhoneSettings(),
            const Divider(),
            const _CatalogShareSettings(),
            const Divider(),
            const _IvaSettings(),
            const ListTile(
              title: Text('Moneda'),
              subtitle: Text('Pesos argentinos (ARS)'),
            ),
            const ListTile(
              title: Text('Datos'),
              subtitle: Text(
                'Catálogo, clientes y pedidos se guardan en la empresa',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RubroSettings extends StatelessWidget {
  const _RubroSettings();

  bool _canEdit(BuildContext context) {
    try {
      return context.watch<SessionStore>().canEditCompanySettings;
    } on ProviderNotFoundException {
      return true;
    }
  }

  Future<void> _apply(BuildContext context, CompanyRubro next) async {
    final store = context.read<AppStore>();
    SessionStore? session;
    try {
      session = context.read<SessionStore>();
    } on ProviderNotFoundException {
      session = null;
    }
    if (session == null) {
      store.setRubro(next);
      return;
    }
    try {
      await session.setCompanyRubro(next);
      store.setRubro(next);
    } on SessionException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _toggle(BuildContext context, {required bool ropa}) {
    final store = context.read<AppStore>();
    var nextRopa = store.rubro.includesRopa;
    var nextCalzado = store.rubro.includesCalzado;
    if (ropa) {
      nextRopa = !nextRopa;
    } else {
      nextCalzado = !nextCalzado;
    }
    if (!nextRopa && !nextCalzado) return;
    unawaited(
      _apply(
        context,
        CompanyRubro.fromSelection(ropa: nextRopa, calzado: nextCalzado),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final canEdit = _canEdit(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: const Text('Rubro'),
          subtitle: Text(
            store.rubro == CompanyRubro.ambos
                ? 'Ropa y calzado. Las categorías muestran las dos líneas.'
                : 'Las categorías corresponden a ${store.rubro.label.toLowerCase()}.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Ropa'),
                selected: store.rubro.includesRopa,
                showCheckmark: true,
                onSelected: canEdit
                    ? (_) => _toggle(context, ropa: true)
                    : null,
              ),
              FilterChip(
                label: const Text('Calzado'),
                selected: store.rubro.includesCalzado,
                showCheckmark: true,
                onSelected: canEdit
                    ? (_) => _toggle(context, ropa: false)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhoneSettings extends StatefulWidget {
  const _PhoneSettings();

  @override
  State<_PhoneSettings> createState() => _PhoneSettingsState();
}

class _PhoneSettingsState extends State<_PhoneSettings> {
  late final TextEditingController _phone;
  String? _saved;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _saved = _sessionPhone();
    _phone = TextEditingController(text: _saved ?? '');
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  bool _canEdit(BuildContext context) {
    try {
      return context.watch<SessionStore>().canEditCompanySettings;
    } on ProviderNotFoundException {
      return true;
    }
  }

  String? _sessionPhone() {
    try {
      return context.read<SessionStore>().company?.phone;
    } on ProviderNotFoundException {
      return null;
    }
  }

  bool get _dirty => blankToNull(_phone.text) != _saved;

  Future<void> _commit() async {
    if (_saving) return;
    final next = blankToNull(_phone.text);
    if (next == _saved) {
      _phone.text = _saved ?? '';
      return;
    }
    final SessionStore session;
    try {
      session = context.read<SessionStore>();
    } on ProviderNotFoundException {
      _saved = next;
      _phone.text = next ?? '';
      return;
    }
    setState(() => _saving = true);
    try {
      await session.setCompanyPhone(next);
      if (!mounted) return;
      _saved = session.company?.phone;
      _phone.text = _saved ?? '';
    } on SessionException catch (error) {
      if (!mounted) return;
      _phone.text = _saved ?? '';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _canEdit(context);
    final canSave = canEdit && _dirty && !_saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(
          title: Text('WhatsApp'),
          subtitle: Text(
            'Número para que tus clientes te contacten desde el catálogo.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('company-phone'),
                  controller: _phone,
                  enabled: canEdit,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Número de teléfono',
                    hintText: '+54 9 11 0000-0000',
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => unawaited(_commit()),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                key: const ValueKey('save-company-phone'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: canSave ? () => unawaited(_commit()) : null,
                child: Text(_saving ? 'Guardando…' : 'Guardar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatalogShareSettings extends StatelessWidget {
  const _CatalogShareSettings();

  @override
  Widget build(BuildContext context) {
    SessionStore? session;
    try {
      session = context.watch<SessionStore>();
    } on ProviderNotFoundException {
      session = null;
    }
    final url = session?.catalogShareUrl();
    final hasPhone = (session?.company?.whatsappDigits ?? '').isNotEmpty;
    final canShare = url != null && hasPhone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          key: const ValueKey('catalog-share'),
          title: const Text('Compartir catálogo'),
          subtitle: Text(
            url == null
                ? 'Enlace para que tus clientes vean las prendas sin iniciar sesión.'
                : canShare
                ? 'Tus clientes arman un pedido y te lo envían por WhatsApp.'
                : 'Configurá tu WhatsApp primero. Es necesario para que tus clientes puedan contactarte.',
          ),
          trailing: canShare
              ? IconButton(
                  tooltip: 'Copiar enlace',
                  onPressed: () => _copy(context, url),
                  icon: const Icon(Icons.copy_outlined),
                )
              : null,
        ),
        if (canShare)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SelectableText(
              url,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
            ),
          ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, String url) async {
    final ok = await copyToClipboard(url);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Copiamos el enlace del catálogo.' : url)),
    );
  }
}

class _IvaSettings extends StatefulWidget {
  const _IvaSettings();

  @override
  State<_IvaSettings> createState() => _IvaSettingsState();
}

class _IvaSettingsState extends State<_IvaSettings> {
  late final TextEditingController _percent;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _percent = TextEditingController(text: PercentFormat.of(store.ivaPercent));
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _percent.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) {
      _commitPercent();
    }
  }

  void _commitPercent() {
    final store = context.read<AppStore>();
    final parsed = PercentFormat.tryParse(_percent.text);
    if (parsed == null) {
      _percent.text = PercentFormat.of(store.ivaPercent);
      return;
    }
    store.setIvaPercent(parsed);
    _percent.text = PercentFormat.of(store.ivaPercent);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Column(
      children: [
        SwitchListTile(
          value: store.ivaEnabled,
          onChanged: store.setIvaEnabled,
          title: const Text('IVA'),
          subtitle: Text(
            store.ivaEnabled
                ? '${PercentFormat.of(store.ivaPercent)}% sobre el subtotal del pedido'
                : 'Desactivado. El total es el subtotal.',
          ),
          activeTrackColor: AppColors.terracotta,
        ),
        if (store.ivaEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              key: const ValueKey('iva-percent'),
              controller: _percent,
              focusNode: _focus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Porcentaje de IVA',
                suffixText: '%',
              ),
              onSubmitted: (_) => _commitPercent(),
            ),
          ),
      ],
    );
  }
}
