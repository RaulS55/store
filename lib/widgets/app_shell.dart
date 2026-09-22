import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/session_store.dart';
import '../theme/tokens.dart';
import 'brand_logo.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _wideDestinations = [
    _Dest('/', 'Stock', Icons.grid_view_rounded, Icons.grid_view_outlined),
    _Dest(
      '/pedido',
      'Pedidos',
      Icons.assignment_rounded,
      Icons.assignment_outlined,
    ),
    _Dest(
      '/producto/nuevo',
      'Nueva prenda',
      Icons.add_circle_rounded,
      Icons.add_circle_outline,
    ),
    _Dest(
      '/clientes',
      'Clientes',
      Icons.people_alt_rounded,
      Icons.people_alt_outlined,
    ),
    _Dest(
      '/lotes',
      'Lotes',
      Icons.inventory_2_rounded,
      Icons.inventory_2_outlined,
    ),
    _Dest('/equipo', 'Equipo', Icons.groups_rounded, Icons.groups_outlined),
    _Dest('/config', 'Config', Icons.settings_rounded, Icons.settings_outlined),
  ];

  static const _mobileDestinations = [
    _Dest('/', 'Stock', Icons.grid_view_rounded, Icons.grid_view_outlined),
    _Dest(
      '/pedido',
      'Pedidos',
      Icons.assignment_rounded,
      Icons.assignment_outlined,
    ),
    _Dest(
      '/producto/nuevo',
      'Nueva',
      Icons.add_circle_rounded,
      Icons.add_circle_outline,
    ),
    _Dest('/mas', 'Más', Icons.more_horiz, Icons.more_horiz),
  ];

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final wide = AppBreakpoints.isWide(context);
    final destinations = _destinationsFor(session, wide);
    if (wide) {
      return _WebShell(destinations: destinations, child: child);
    }
    return _MobileShell(destinations: destinations, child: child);
  }

  static List<_Dest> _destinationsFor(SessionStore session, bool wide) {
    final all = wide ? _wideDestinations : _mobileDestinations;
    return [
      for (final dest in all)
        if (_canShow(session, dest)) dest,
    ];
  }

  static bool _canShow(SessionStore session, _Dest dest) {
    if (dest.path == '/equipo') return session.canViewTeam;
    if (dest.path == '/lotes') return session.canManageLots;
    return true;
  }
}

class _Dest {
  const _Dest(this.path, this.label, this.selected, this.unselected);
  final String path;
  final String label;
  final IconData selected;
  final IconData unselected;
}

int _indexFor(String location, List<_Dest> dests) {
  var best = 0;
  var bestLen = -1;
  for (var i = 0; i < dests.length; i++) {
    final path = dests[i].path;
    final match =
        location == path || (path != '/' && location.startsWith(path));
    if (match && path.length > bestLen) {
      best = i;
      bestLen = path.length;
    }
  }
  if (location.startsWith('/producto/') && location != '/producto/nuevo') {
    return dests.indexWhere((d) => d.path == '/');
  }
  return best;
}

bool _hideMobileNav(String location) {
  if (location.endsWith('/facturar')) return true;
  if (location.startsWith('/producto/') && location != '/producto/nuevo') {
    return true;
  }
  if (location.startsWith('/clientes/') && location != '/clientes') {
    return true;
  }
  if (location.startsWith('/lotes/') && location != '/lotes') {
    return true;
  }
  return false;
}

class _WebShell extends StatelessWidget {
  const _WebShell({required this.child, required this.destinations});

  final Widget child;
  final List<_Dest> destinations;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final location = GoRouterState.of(context).uri.path;
    final selected = _indexFor(location, destinations);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = session.user?.displayName ?? '';
    final role = session.membership?.role.label ?? '';
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 248,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                right: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
                  child: BrandLogo(),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: destinations.length,
                    itemBuilder: (context, index) {
                      final dest = destinations[index];
                      final active = index == selected;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          onTap: () => context.go(dest.path),
                          selected: active,
                          leading: Icon(
                            active ? dest.selected : dest.unselected,
                            color: active
                                ? AppColors.terracotta
                                : AppColors.slate,
                          ),
                          title: Text(dest.label),
                          selectedTileColor: isDark
                              ? AppColors.terracotta.withValues(alpha: 0.18)
                              : AppColors.terracottaChip,
                          textColor: active
                              ? AppColors.terracotta
                              : Theme.of(context).colorScheme.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          dense: true,
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.terracottaSoft,
                        child: Text(
                          initial,
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
                              name,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              role,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.mutedText),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar sesión',
                        onPressed: session.isBusy ? null : session.signOut,
                        icon: const Icon(Icons.logout, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.child, required this.destinations});

  final Widget child;
  final List<_Dest> destinations;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selected = _indexFor(location, destinations);
    final hideNav = _hideMobileNav(location);
    final media = MediaQuery.of(context);
    final keyboardInset = kIsWeb ? 0.0 : media.viewInsets.bottom;
    final content = hideNav
        ? child
        : MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: child,
          );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: content,
            ),
          ),
          if (!hideNav)
            _MobileNavBar(
              destinations: destinations,
              selectedIndex: selected.clamp(0, destinations.length - 1),
            ),
        ],
      ),
    );
  }
}

class _MobileNavBar extends StatelessWidget {
  const _MobileNavBar({
    required this.destinations,
    required this.selectedIndex,
  });

  final List<_Dest> destinations;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final navMedia = kIsWeb
        ? media.copyWith(
            padding: media.padding.copyWith(bottom: 0),
            viewPadding: media.viewPadding.copyWith(bottom: 0),
            viewInsets: EdgeInsets.zero,
          )
        : media;

    return MediaQuery(
      data: navMedia,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            context.go(destinations[index].path);
          },
          destinations: [
            for (final dest in destinations)
              NavigationDestination(
                icon: Icon(dest.unselected),
                selectedIcon: Icon(dest.selected),
                label: dest.label,
              ),
          ],
        ),
      ),
    );
  }
}
