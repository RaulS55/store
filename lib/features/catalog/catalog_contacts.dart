import 'package:flutter/material.dart';

import '../../data/order_share.dart';
import '../../models/company.dart';
import '../../theme/tokens.dart';

class CatalogContactLink {
  const CatalogContactLink({
    required this.id,
    required this.label,
    required this.icon,
    required this.uri,
    this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final Uri uri;
  final Color? color;
}

List<CatalogContactLink> catalogContactLinks(Company company) {
  final links = <CatalogContactLink>[];
  final digits = company.whatsappDigits;
  if (digits.isNotEmpty) {
    links.add(
      CatalogContactLink(
        id: 'catalog-whatsapp',
        label: 'WhatsApp',
        icon: Icons.chat_outlined,
        uri: Uri.parse('https://wa.me/$digits'),
        color: AppColors.whatsapp,
      ),
    );
  }
  final instagram = company.instagramUrl;
  if (instagram != null) {
    links.add(
      CatalogContactLink(
        id: 'catalog-instagram',
        label: _socialLabel('Instagram', company.instagram),
        icon: Icons.photo_camera_outlined,
        uri: Uri.parse(instagram),
      ),
    );
  }
  final tiktok = company.tiktokUrl;
  if (tiktok != null) {
    links.add(
      CatalogContactLink(
        id: 'catalog-tiktok',
        label: _socialLabel('TikTok', company.tiktok),
        icon: Icons.music_note_outlined,
        uri: Uri.parse(tiktok),
      ),
    );
  }
  final facebook = company.facebookUrl;
  if (facebook != null) {
    links.add(
      CatalogContactLink(
        id: 'catalog-facebook',
        label: _socialLabel('Facebook', company.facebook),
        icon: Icons.public_outlined,
        uri: Uri.parse(facebook),
      ),
    );
  }
  return links;
}

String _socialLabel(String platform, String? raw) {
  final value = blankToNull(raw);
  if (value == null) return platform;
  if (value.contains('://') || value.contains('.')) return platform;
  final handle = value.replaceFirst(RegExp(r'^@+'), '').trim();
  if (handle.isEmpty || handle.length > 22) return platform;
  return '$platform · @$handle';
}

class CatalogContacts extends StatelessWidget {
  const CatalogContacts({super.key, required this.company});

  final Company company;

  @override
  Widget build(BuildContext context) {
    final links = catalogContactLinks(company);
    if (links.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('catalog-contacts'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contacto',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final link in links)
              ActionChip(
                key: ValueKey(link.id),
                avatar: Icon(link.icon, size: 18, color: link.color),
                label: Text(link.label),
                onPressed: () => _open(context, link),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context, CatalogContactLink link) async {
    final ok = await OrderShare.openUri(link.uri);
    if (!context.mounted || ok) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('No se pudo abrir ${link.label}.')));
  }
}
