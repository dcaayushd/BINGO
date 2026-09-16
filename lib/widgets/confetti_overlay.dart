import 'dart:math';

import 'package:flutter/material.dart';

/// A small, dependency-free celebratory effect. It paints only while active,
/// then removes itself from the render pipeline.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, required this.active});

  final bool active;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
    final random = Random(18);
    _particles = List<_Particle>.generate(
      42,
      (_) => _Particle(
        x: random.nextDouble(),
        speed: .35 + random.nextDouble() * .65,
        drift: random.nextDouble() * 2 - 1,
        rotation: random.nextDouble() * pi,
        color: <Color>[
          const Color(0xFFB8E3D0),
          const Color(0xFFFFFFFF),
          const Color(0xFFF7C948),
          const Color(0xFF69D2E7),
          const Color(0xFFFF8A80),
        ][random.nextInt(5)],
      ),
    );
    if (widget.active) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: _ConfettiPainter(_particles, _controller.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.x,
    required this.speed,
    required this.drift,
    required this.rotation,
    required this.color,
  });

  final double x;
  final double speed;
  final double drift;
  final double rotation;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.particles, this.progress);

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = progress < .82 ? 1.0 : (1 - progress) / .18;
    for (final particle in particles) {
      final y = size.height * (progress * particle.speed * 1.05 - .12);
      if (y < -12 || y > size.height + 16) continue;
      final x = size.width * particle.x +
          sin(progress * pi * 3 + particle.rotation) * 26 * particle.drift;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotation + progress * pi * 4 * particle.drift);
      final paint = Paint()..color = particle.color.withValues(alpha: opacity);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 8, height: 12),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
