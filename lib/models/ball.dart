import 'dart:ui';

/// La bille en métal qui tombe/roule dans le jeu.
class Ball {
  Offset position;
  Offset velocity;
  final double radius;

  Ball({
    required this.position,
    this.velocity = Offset.zero,
    this.radius = 12,
  });

  void applyGravity(double dt, {double gravity = 900}) {
    velocity += Offset(0, gravity * dt);
  }

  void updatePosition(double dt) {
    position += velocity * dt;
  }
}
