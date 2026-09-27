import 'dart:ui';

class CollisionResult {
  final bool hit;
  final Offset normal;
  final Offset closestPoint;
  const CollisionResult(this.hit, this.normal, this.closestPoint);
}

/// Teste la collision entre une bille (cercle) et un segment [a, b] (la règle).
CollisionResult ballRulerCollision(
  Offset ballPos,
  double radius,
  Offset a,
  Offset b,
) {
  final ab = b - a;
  final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;

  double t = abLenSq == 0
      ? 0
      : ((ballPos - a).dx * ab.dx + (ballPos - a).dy * ab.dy) / abLenSq;
  t = t.clamp(0.0, 1.0);

  final closest = a + ab * t;
  final diff = ballPos - closest;
  final dist = diff.distance;

  if (dist <= radius) {
    final normal = dist == 0 ? const Offset(0, -1) : diff / dist;
    return CollisionResult(true, normal, closest);
  }
  return CollisionResult(false, Offset.zero, closest);
}
