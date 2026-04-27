import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../controllers/navigation_controller.dart';
import '../../data/cairo_web_preview_data.dart';

/// Styling-only map for web preview: gradient “sky”, route polyline, optional puck and markers.
class CairoMapPreview extends StatelessWidget {
  const CairoMapPreview({
    super.key,
    required this.routeLngLat,
    this.userPosition,
    this.destinationLngLat,
    this.showTraffic = false,
    this.padding = 24,
  });

  final List<List<double>> routeLngLat;
  final geo.Position? userPosition;
  final List<double>? destinationLngLat; // [lng, lat]
  final bool showTraffic;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            size: Size(c.maxWidth, c.maxHeight),
            painter: _CairoMapPainter(
              route: routeLngLat,
              user: userPosition,
              dest: destinationLngLat,
              traffic: showTraffic,
              pad: padding,
            ),
          ),
        );
      },
    );
  }
}

class _CairoMapPainter extends CustomPainter {
  _CairoMapPainter({
    required this.route,
    this.user,
    this.dest,
    required this.traffic,
    required this.pad,
  });

  final List<List<double>> route;
  final geo.Position? user;
  final List<double>? dest;
  final bool traffic;
  final double pad;

  @override
  void paint(Canvas cv, Size size) {
    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF5C9DFF),
          Color(0xFF8BC0FF),
          Color(0xFFE8DCC6),
        ],
        stops: [0, 0.45, 1],
      ).createShader(r);
    cv.drawRect(r, bg);

    if (route.length >= 2) {
      var minX = route.first[0];
      var maxX = minX;
      var minY = route.first[1];
      var maxY = minY;
      for (final p in route) {
        minX = math.min(minX, p[0]);
        maxX = math.max(maxX, p[0]);
        minY = math.min(minY, p[1]);
        maxY = math.max(maxY, p[1]);
      }
      if (user != null) {
        minX = math.min(minX, user!.longitude);
        maxX = math.max(maxX, user!.longitude);
        minY = math.min(minY, user!.latitude);
        maxY = math.max(maxY, user!.latitude);
      }
      if (dest != null && dest!.length >= 2) {
        minX = math.min(minX, dest![0]);
        maxX = math.max(maxX, dest![0]);
        minY = math.min(minY, dest![1]);
        maxY = math.max(maxY, dest![1]);
      }
      final dx = (maxX - minX) * 0.12;
      final dy = (maxY - minY) * 0.12;
      minX -= dx;
      maxX += dx;
      minY -= dy;
      maxY += dy;

      Offset toScreen(double lng, double lat) {
        final u = (lng - minX) / (maxX - minX + 1e-9);
        final v = 1.0 - (lat - minY) / (maxY - minY + 1e-9);
        return Offset(
          pad + u * (size.width - 2 * pad),
          pad + v * (size.height - 2 * pad),
        );
      }

      if (traffic) {
        _drawTrafficRibbons(cv, route, toScreen, size);
      }

      final path = Path()..moveTo(toScreen(route[0][0], route[0][1]).dx, toScreen(route[0][0], route[0][1]).dy);
      for (var i = 1; i < route.length; i++) {
        final o = toScreen(route[i][0], route[i][1]);
        path.lineTo(o.dx, o.dy);
      }
      cv.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      cv.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF1A73E8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      if (dest != null && dest!.length >= 2) {
        final o = toScreen(dest![0], dest![1]);
        cv.drawCircle(o, 12, Paint()..color = Colors.white);
        cv.drawCircle(o, 9, Paint()..color = const Color(0xFFE53935));
      }

      if (user != null) {
        final o = toScreen(user!.longitude, user!.latitude);
        cv.drawCircle(o, 14, Paint()..color = const Color(0x401A73E8));
        cv.drawCircle(o, 7, Paint()..color = const Color(0xFF1A73E8));
      }
    } else {
      // Fallback text
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Cairo — web preview',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        cv,
        Offset((size.width - tp.width) / 2, 24),
      );
    }
  }

  void _drawTrafficRibbons(
    Canvas cv,
    List<List<double>> route,
    Offset Function(double, double) toScreen,
    Size size,
  ) {
    for (var i = 0; i < route.length - 1; i += 2) {
      final a = toScreen(route[i][0], route[i][1]);
      final b = toScreen(
        route[math.min(i + 1, route.length - 1)][0],
        route[math.min(i + 1, route.length - 1)][1],
      );
      final color = (i % 3 == 0)
          ? const Color(0x40FF8C1A)
          : (i % 3 == 1)
              ? const Color(0x3039C66D)
              : const Color(0x45FF0015);
      final m = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      cv.drawCircle(m, 16, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _CairoMapPainter oldDelegate) {
    return oldDelegate.route != route ||
        oldDelegate.user != user ||
        oldDelegate.dest != dest ||
        oldDelegate.traffic != traffic;
  }
}

/// Web navigation screen map: uses controller for route and live position.
class WebNavigationMapPreview extends StatelessWidget {
  const WebNavigationMapPreview({
    super.key,
    required this.controller,
    required this.destinationLat,
    required this.destinationLng,
    required this.onUserPan,
  });

  final NavigationController controller;
  final double destinationLat;
  final double destinationLng;
  final VoidCallback onUserPan;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final route = controller.route;
        final pts = route?.coordinates ?? CairoWebPreviewData.staticDemoRoute.coordinates;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (_) => onUserPan(),
          child: CairoMapPreview(
            routeLngLat: pts,
            userPosition: controller.lastPosition,
            destinationLngLat: [destinationLng, destinationLat],
            showTraffic: true,
            padding: 16,
          ),
        );
      },
    );
  }
}
