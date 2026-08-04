import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_theme.dart';

class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final int burst;

  const ConfettiOverlay({super.key, required this.child, required this.burst});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with TickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 3500);

  final _bursts = <_Burst>[];
  final _rng = Random();
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      _elapsed = elapsed;
      _pruneCompleted();
      if (_bursts.isEmpty) {
        _ticker.stop();
      }
      setState(() {});
    });
    if (widget.burst > 0) {
      _addBurst();
    }
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.burst > oldWidget.burst) {
      _addBurst();
    }
  }

  void _addBurst() {
    _bursts.add(_Burst(_elapsed, _generateParticles()));
    if (!_ticker.isActive) {
      _ticker.start();
    }
    // No setState here: didUpdateWidget is called during build, so
    // calling setState would throw. The ticker's next tick (or the
    // first tick after start) will repaint with the new burst.
  }

  void _pruneCompleted() {
    _bursts.removeWhere((b) => _elapsed - b.start >= _duration);
  }

  List<_Sparkle> _generateParticles() {
    final particles = <_Sparkle>[];
    // Stars / sparkles
    for (var i = 0; i < 280; i++) {
      particles.add(_Sparkle(
        x: 0.3 + _rng.nextDouble() * 0.4,
        y: -0.15 - _rng.nextDouble() * 0.15,
        color: AppColors
            .confettiColors[_rng.nextInt(AppColors.confettiColors.length)],
        size: 10 + _rng.nextDouble() * 8,
        velocityX: (_rng.nextDouble() - 0.5) * 0.6,
        velocityY: 0.4 + _rng.nextDouble() * 0.6,
        rotation: _rng.nextDouble() * 6.28,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 8,
        type: _rng.nextDouble() > 0.5
            ? _SparkleType.star
            : _SparkleType.sparkle,
      ));
    }
    // Small dots / sparkle dust
    for (var i = 0; i < 200; i++) {
      particles.add(_Sparkle(
        x: 0.4 + _rng.nextDouble() * 0.2,
        y: -0.05 - _rng.nextDouble() * 0.1,
        color: AppColors.textPrimary
            .withValues(alpha: 0.7 + _rng.nextDouble() * 0.3),
        size: 1.5 + _rng.nextDouble() * 2.5,
        velocityX: (_rng.nextDouble() - 0.5) * 0.3,
        velocityY: 0.5 + _rng.nextDouble() * 0.4,
        rotation: 0,
        rotationSpeed: 0,
        type: _SparkleType.dot,
      ));
    }
    return particles;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_bursts.isNotEmpty)
          // IgnorePointer ensures the confetti layer never intercepts
          // taps/clicks — the user can keep interacting with the UI
          // underneath while the celebration plays.
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                isComplex: true,
                willChange: true,
                painter: _ConfettiPainter(_bursts, _elapsed),
              ),
            ),
          ),
      ],
    );
  }
}

class _Burst {
  final Duration start;
  final List<_Sparkle> particles;

  _Burst(this.start, this.particles);
}

enum _SparkleType { star, sparkle, dot }

class _Sparkle {
  final double x, y;
  final Color color;
  final double size;
  final double velocityX, velocityY;
  final double rotation, rotationSpeed;
  final _SparkleType type;
  // Pre-built star path so paint() doesn't rebuild it every frame.
  final Path? starPath;

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
  }) : starPath =
            type == _SparkleType.star ? _buildStarPath(size) : null;

  static Path _buildStarPath(double size) {
    final path = Path();
    const points = 4;
    final outer = size / 2;
    final inner = size / 5;
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = pi * 2 * i / (points * 2) - pi / 2;
      final x = radius * cos(angle);
      final y = radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Burst> bursts;
  final Duration elapsed;

  _ConfettiPainter(this.bursts, this.elapsed);

  @override
  void paint(Canvas canvas, Size size) {
    // Reused paints: allocating Paint is cheap, but MaskFilter.blur is not.
    // We avoid blur entirely and fake the glow with a larger low-alpha
    // circle, keeping per-frame cost to a few draw calls per particle.
    final solidPaint = Paint()..style = PaintingStyle.fill;
    final glowPaint = Paint()..style = PaintingStyle.fill;

    for (final burst in bursts) {
      final t = ((elapsed - burst.start).inMilliseconds /
              _ConfettiOverlayState._duration.inMilliseconds)
          .clamp(0.0, 1.0);
      final progress = Curves.easeOutCubic.transform(t);
      for (final p in burst.particles) {
        final px = (p.x + p.velocityX * progress * 1.3) * size.width;
        final py = (p.y + p.velocityY * progress * 1.3) * size.height;
        if (py > size.height + 30 || py < -30) continue;

        final fadeOut = progress > 0.6 ? (1 - (progress - 0.6) / 0.4) : 1.0;
        if (fadeOut <= 0) continue;

        canvas.save();
        canvas.translate(px, py);
        canvas.rotate(p.rotation + p.rotationSpeed * progress);

        // Soft halo: a plain circle with low alpha, no blur filter.
        glowPaint.color = p.color
            .withValues(alpha: 0.15 * (1 - progress) * fadeOut);
        canvas.drawCircle(Offset.zero, p.size * 0.9, glowPaint);

        final alpha = p.color.a * fadeOut;
        solidPaint.color = p.color.withValues(alpha: alpha);

        switch (p.type) {
          case _SparkleType.star:
            canvas.drawPath(p.starPath!, solidPaint);
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
              solidPaint,
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
              solidPaint,
            );
            break;
          case _SparkleType.dot:
            canvas.drawCircle(Offset.zero, p.size * 0.5, solidPaint);
            break;
        }

        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.elapsed != elapsed || oldDelegate.bursts != bursts;
  }
}