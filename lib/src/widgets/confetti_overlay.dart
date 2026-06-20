import 'package:flutter/material.dart';
import 'dart:math';
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
  final _particles = <_ConfettiParticle>[];
  final _rng = Random();

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
    for (var i = 0; i < 40; i++) {
      _particles.add(_ConfettiParticle(
        x: 0.5 + (_rng.nextDouble() - 0.5) * 0.8,
        y: -0.1,
        color: HabitColors.accentColors[_rng.nextInt(HabitColors.accentColors.length)],
        size: 4 + _rng.nextDouble() * 6,
        velocityX: (_rng.nextDouble() - 0.5) * 0.4,
        velocityY: 0.3 + _rng.nextDouble() * 0.5,
        rotation: _rng.nextDouble() * 6.28,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 6,
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

class _ConfettiParticle {
  final double x, y;
  final Color color;
  final double size;
  final double velocityX, velocityY;
  final double rotation, rotationSpeed;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.velocityX,
    required this.velocityY,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final px = (p.x + p.velocityX * progress * 2) * size.width;
      final py = (p.y + p.velocityY * progress * 2) * size.height;
      if (py > size.height + 20 || py < -20) continue;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation + p.rotationSpeed * progress);

      final fadeOut = progress > 0.7 ? (1 - (progress - 0.7) / 0.3) : 1.0;
      final paint = Paint()
        ..color = p.color.withValues(alpha: fadeOut)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}