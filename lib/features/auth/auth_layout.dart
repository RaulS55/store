import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = AppBreakpoints.isWide(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formColor = isDark ? AppColors.darkBg : Colors.white;
    return Scaffold(
      backgroundColor: formColor,
      body: wide
          ? Row(
              children: [
                const Expanded(child: _AuthBrandPanel()),
                Expanded(
                  child: _AuthFormPane(
                    title: title,
                    subtitle: subtitle,
                    child: child,
                  ),
                ),
              ],
            )
          : SafeArea(
              child: _AuthFormPane(
                title: title,
                subtitle: subtitle,
                child: child,
              ),
            ),
    );
  }
}

class _AuthFormPane extends StatelessWidget {
  const _AuthFormPane({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(10);
    final border = BorderSide(
      color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
    );
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.terracotta,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.terracotta.withValues(
              alpha: 0.5,
            ),
            elevation: 0,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: radius),
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
            minimumSize: const Size.fromHeight(50),
            side: border,
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.terracotta,
            textStyle: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: isDark ? AppColors.darkElevated : Colors.white,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.mutedText,
          ),
          prefixIconColor: AppColors.mutedText,
          suffixIconColor: AppColors.mutedText,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          border: OutlineInputBorder(borderRadius: radius, borderSide: border),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: border,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(
              color: AppColors.terracotta,
              width: 1.4,
            ),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - 64),
                maxWidth: 400,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AuthHanger(
                        size: 40,
                        color: isDark
                            ? const Color(0xFFF3F4F6)
                            : AppColors.charcoal,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.charcoal,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.mutedText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.terracotta,
      child: Column(
        children: [
          const Expanded(
            flex: 4,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: FittedBox(fit: BoxFit.scaleDown, child: _BrandWordmark()),
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: Column(
                children: [
                  const Expanded(
                    flex: 3,
                    child: _BrandPhoto('assets/products/jacket_beige.jpg'),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: _BrandPhoto('assets/products/bag.jpg'),
                              ),
                              SizedBox(height: 10),
                              Expanded(
                                child: _BrandPhoto(
                                  'assets/products/sneakers_white.jpg',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: _BrandPhoto('assets/products/oxford.jpg'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandWordmark extends StatelessWidget {
  const _BrandWordmark();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AuthHanger(size: 64, color: Colors.white),
        SizedBox(height: 20),
        Text(
          'Moda Stock',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 52,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 1.05,
            letterSpacing: -0.6,
          ),
        ),
        SizedBox(height: 16),
        _BrandDiamond(),
        SizedBox(height: 16),
        Text(
          'Gestioná indumentaria y calzado',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _BrandDiamond extends StatelessWidget {
  const _BrandDiamond();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: 8,
        height: 8,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}

class _BrandPhoto extends StatelessWidget {
  const _BrandPhoto(this.path);

  final String path;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0x33FFFFFF)),
          ),
          ColoredBox(color: AppColors.terracotta.withValues(alpha: 0.16)),
        ],
      ),
    );
  }
}

class _AuthHanger extends StatelessWidget {
  const _AuthHanger({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        size: Size(size, size),
        painter: _HangerPainter(color),
      ),
    );
  }
}

class _HangerPainter extends CustomPainter {
  const _HangerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final hook = Path()
      ..moveTo(size.width * 0.50, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.04,
        size.width * 0.64,
        size.height * 0.12,
      );
    final body = Path()
      ..moveTo(size.width * 0.10, size.height * 0.82)
      ..lineTo(size.width * 0.50, size.height * 0.32)
      ..lineTo(size.width * 0.90, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.94,
        size.width * 0.10,
        size.height * 0.82,
      );

    canvas.drawPath(hook, paint);
    canvas.drawPath(body, paint);
  }

  @override
  bool shouldRepaint(covariant _HangerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
