import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../data/order_share.dart';
import '../../models/company.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_snack_bar.dart';

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
  final FaIconData icon;
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
        icon: FontAwesomeIcons.whatsapp,
        uri: Uri.parse('https://wa.me/$digits'),
        color: AppColors.whatsapp,
      ),
    );
  }
  _addSocials(
    links,
    id: 'catalog-instagram',
    platform: 'Instagram',
    accounts: company.instagram,
    host: 'www.instagram.com',
    icon: FontAwesomeIcons.instagram,
    color: AppColors.instagram,
  );
  _addSocials(
    links,
    id: 'catalog-tiktok',
    platform: 'TikTok',
    accounts: company.tiktok,
    host: 'www.tiktok.com',
    icon: FontAwesomeIcons.tiktok,
    atHandle: true,
  );
  _addSocials(
    links,
    id: 'catalog-facebook',
    platform: 'Facebook',
    accounts: company.facebook,
    host: 'www.facebook.com',
    icon: FontAwesomeIcons.facebook,
    color: AppColors.facebook,
  );
  return links;
}

void _addSocials(
  List<CatalogContactLink> links, {
  required String id,
  required String platform,
  required List<String> accounts,
  required String host,
  required FaIconData icon,
  Color? color,
  bool atHandle = false,
}) {
  for (var index = 0; index < accounts.length; index++) {
    final raw = accounts[index];
    final url = socialProfileUrl(raw, host: host, atHandle: atHandle);
    if (url == null) continue;
    links.add(
      CatalogContactLink(
        id: '$id-$index',
        label: _socialLabel(platform, raw),
        icon: icon,
        uri: Uri.parse(url),
        color: color,
      ),
    );
  }
}

String _socialLabel(String platform, String? raw) {
  final value = blankToNull(raw);
  if (value == null) return platform;
  var handle = value;
  final parsed = Uri.tryParse(value);
  if (parsed != null &&
      (parsed.scheme == 'http' || parsed.scheme == 'https') &&
      parsed.pathSegments.isNotEmpty) {
    handle = parsed.pathSegments.last;
  }
  handle = handle.replaceFirst(RegExp(r'^@+'), '').trim();
  handle = handle.replaceFirst(
    RegExp(
      r'^(www\.)?(instagram\.com|tiktok\.com|facebook\.com|fb\.com)/',
      caseSensitive: false,
    ),
    '',
  );
  handle = handle
      .replaceFirst(RegExp(r'^@+'), '')
      .replaceFirst(RegExp(r'^/+'), '');
  if (handle.isEmpty ||
      handle.contains('/') ||
      handle.contains(' ') ||
      handle.contains('?') ||
      handle.length > 22) {
    return platform;
  }
  return '$platform · @$handle';
}

class CatalogContacts extends StatelessWidget {
  const CatalogContacts({super.key, required this.company});

  final Company company;

  @override
  Widget build(BuildContext context) {
    final links = catalogContactLinks(company);
    if (links.isEmpty) return const SizedBox.shrink();
    final onIcon = Theme.of(context).colorScheme.surface;
    return Wrap(
      key: const ValueKey('catalog-contacts'),
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final link in links)
          IconButton(
            key: ValueKey(link.id),
            tooltip: link.label,
            onPressed: () => _open(context, link),
            style: IconButton.styleFrom(
              backgroundColor:
                  link.color ?? Theme.of(context).colorScheme.onSurface,
              foregroundColor: onIcon,
              minimumSize: const Size(40, 40),
              fixedSize: const Size(40, 40),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: FaIcon(link.icon, size: 18, color: onIcon),
          ),
      ],
    );
  }

  Future<void> _open(BuildContext context, CatalogContactLink link) async {
    final ok = await OrderShare.openUri(link.uri);
    if (!context.mounted || ok) return;
    AppSnackBar.show(context, content: Text('No se pudo abrir ${link.label}.'));
  }
}
