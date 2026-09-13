import 'dart:io';
import 'dart:math';

import 'package:image/image.dart';

/// Terracotta from [AppColors.terracotta].
const _terracotta = (196, 92, 62);

void main() {
  _writePng('web/favicon.png', _logo(48));
  _writePng('web/icons/Icon-192.png', _logo(192));
  _writePng('web/icons/Icon-512.png', _logo(512));
  _writePng('web/icons/Icon-maskable-192.png', _logo(192, inset: 0.18));
  _writePng('web/icons/Icon-maskable-512.png', _logo(512, inset: 0.18));
  _writePng('web/og-image.png', _ogImage(1200, 630));
}

void _writePng(String path, Image image) {
  File(path).writeAsBytesSync(encodePng(image));
}

Image _logo(int size, {double inset = 0.12}) {
  final image = Image(width: size, height: size);
  fill(image, color: ColorRgb8(_terracotta.$1, _terracotta.$2, _terracotta.$3));
  _drawHanger(image, inset: inset);
  return image;
}

Image _ogImage(int width, int height) {
  final image = Image(width: width, height: height);
  fill(image, color: ColorRgb8(_terracotta.$1, _terracotta.$2, _terracotta.$3));
  final side = (min(width, height) * 0.62).round();
  final left = ((width - side) / 2).round();
  final top = ((height - side) / 2).round();
  _drawHanger(
    image,
    originX: left.toDouble(),
    originY: top.toDouble(),
    size: side.toDouble(),
    inset: 0.04,
  );
  return image;
}

void _drawHanger(
  Image image, {
  double originX = 0,
  double originY = 0,
  double? size,
  required double inset,
}) {
  final canvas = size ?? image.width.toDouble();
  final pad = canvas * inset;
  final box = canvas - pad * 2;
  final stroke = max(1.5, box * 0.055);
  final white = ColorRgb8(255, 255, 255);

  Offset map(double x, double y) {
    return Offset(originX + pad + x * box, originY + pad + y * box);
  }

  final points = [
    ..._quad(map(0.50, 0.28), map(0.50, 0.04), map(0.64, 0.12)),
    ..._line(map(0.10, 0.82), map(0.50, 0.32)),
    ..._line(map(0.50, 0.32), map(0.90, 0.82)),
    ..._quad(map(0.90, 0.82), map(0.50, 0.94), map(0.10, 0.82)),
  ];
  _stroke(image, points, white, stroke);
}

List<Offset> _line(Offset a, Offset b) {
  final steps = max(8, (a.distanceTo(b) * 2).ceil());
  return [
    for (var i = 0; i <= steps; i++)
      Offset(a.x + (b.x - a.x) * i / steps, a.y + (b.y - a.y) * i / steps),
  ];
}

List<Offset> _quad(Offset p0, Offset p1, Offset p2) {
  final steps = max(24, ((p0.distanceTo(p1) + p1.distanceTo(p2)) * 2).ceil());
  return [for (var i = 0; i <= steps; i++) _quadPoint(p0, p1, p2, i / steps)];
}

Offset _quadPoint(Offset p0, Offset p1, Offset p2, double t) {
  final u = 1 - t;
  return Offset(
    u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
    u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y,
  );
}

void _stroke(Image image, List<Offset> points, Color color, double width) {
  final radius = max(1, (width / 2).round());
  for (final point in points) {
    fillCircle(
      image,
      x: point.x.round(),
      y: point.y.round(),
      radius: radius,
      color: color,
      antialias: true,
    );
  }
}

class Offset {
  const Offset(this.x, this.y);
  final double x;
  final double y;

  double distanceTo(Offset other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }
}
