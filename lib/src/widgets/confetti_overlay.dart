import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/habit_colors.dart';

class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final bool show;

  const ConfettiOverlay({super.key, required this.child, required this.show});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final _particles = <_Sparkle>[];
  final _rng = Random();

  final _sparkleColors = [
    const Color(0xFFFFD700), // gold
    const Color(0xFFFF69B4), // hot pink
    const Color(0xFF00FFFF), // cyan
    const Color(0xFFFF4500), // orange red
    const Color(0xFF7FFF00), // chartreuse
    const Color(0xFFFF00FF), // magenta
    const Color(0xFF00BFFF), // deep sky blue
    const Color(0xFFFFD700), // gold
    const Color(0xFFFF1493), // deep pink
    const Color(0xFFADFF2F), // green yellow
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _particles.clear());
      }
    });
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _burst();
    }
  }

  void _burst() {
    _particles.clear();
    // Stars
    for (var i = 0; i < 100; i++) {
      _particles.add(_Sparkle(
        x: 0.3 + _rng.nextDouble() * 0.4,
        y: -0.15 - _rng.nextDouble() * 0.15,
        color: _sparkleColors[_rng.nextInt(_sparkleColors.length)],
        size: 10 + _rng.nextDouble() * 8,
        velocityX: (_rng.nextDouble() - 0.5) * 0.6,
        velocityY: 0.4 + _rng.nextDouble() * 0.6,
        rotation: _rng.nextDouble() * 6.28,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 8,
        type: _rng.nextDouble() > 0.5 ? _SparkleType.star : _SparkleType.sparkle,
      ));
    }
    // Small dots / sparkle dust
    for (var i = 0; i < 125; i++) {
      _particles.add(_Sparkle(
        x: 0.4 + _rng.nextDouble() * 0.2,
        y: -0.05 - _rng.nextDouble() * 0.1,
        color: Colors.white.withValues(alpha: 0.7 + _rng.nextDouble() * 0.3),
        size: 1.5 + _rng.nextDouble() * 2.5,
        velocityX: (_rng.nextDouble() - 0.5) * 0.3,
        velocityY: 0.5 + _rng.nextDouble() * 0.4,
        rotation: 0,
        rotationSpeed: 0,
        type: _SparkleType.dot,
      ));
    }
    _controller.reset();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_particles.isNotEmpty)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = _controller.value;
              final eased = Curves.easeOutCubic.transform(progress);
              return CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(_particles, eased),
              );
            },
          ),
      ],
    );
  }
}

enum _SparkleType { star, sparkle, dot }

class _Sparkle {
  final double x, y;
  final Color color;
  final double size;
  final double velocityX, velocityY;
  final double rotation, rotationSpeed;
  final _SparkleType type;

  _Sparkle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.velocityX,
    required this.velocityY,
    required this.rotation,
    required this.rotationSpeed,
    required this.type,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Sparkle> particles;
  final double progress;

  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final px = (p.x + p.velocityX * progress * 2) * size.width;
      final py = (p.y + p.velocityY * progress * 2) * size.height;
      if (py > size.height + 30 || py < -30) continue;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation + p.rotationSpeed * progress);

      // Glow effect
      final glowPaint = Paint()
        ..color = p.color.withValues(alpha: 0.2 * (1 - progress))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset.zero, p.size * 0.8, glowPaint);

      final fadeOut = progress > 0.6 ? (1 - (progress - 0.6) / 0.4) : 1.0;
      final alpha = (p.color.alpha * fadeOut / 255).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      switch (p.type) {
        case _SparkleType.star:
          _drawStar(canvas, Offset.zero, p.size, paint);
          break;
        case _SparkleType.sparkle:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: p.size,
                height: p.size * 0.4,
              ),
              const Radius.circular(2),
            ),
            paint,
          );
          // Second perpendicular strip for a sparkle cross
          canvas.rotate(1.57);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: p.size * 0.7,
                height: p.size * 0.4,
              ),
              const Radius.circular(2),
            ),
            paint,
          );
          break;
        case _SparkleType.dot:
          canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
          break;
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final points = 4;
    final outer = size / 2;
    final inner = size / 5;
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = pi * 2 * i / (points * 2) - pi / 2;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}