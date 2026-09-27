import 'dart:math';
import 'dart:ui';

/// Une règle-plateforme à la forme fixe (longueur fixe, horizontale au départ).
/// Le joueur ne la dessine plus : il choisit juste où elle est posée.
/// Une fois posée, elle devient de plus en plus instable : son angle dérive
/// dans le temps jusqu'à ce que la bille n'ait plus assez d'adhérence.
/// Le sens de rotation (horaire/anti-horaire) est tiré au hasard à chaque
/// création, pour que chaque règle se comporte différemment.
class Ruler {
  Offset center;
  final double baseAngle;
  final double length;
  double age = 0; // secondes écoulées depuis la pose

  final double instabilityDelay;
  late final double instabilitySpeed; // signe aléatoire : sens de rotation

  /// Obstacle fixe d'une chambre : ne devient jamais instable, rendu dans un
  /// style différent des règles posées par le joueur.
  final bool isStatic;

  static final Random _random = Random();

  Ruler({
    required this.center,
    this.baseAngle = 0, // horizontale par défaut
    this.length = 110,
    this.instabilityDelay = 2.5,
    double instabilityMagnitude = 0.6,
    this.isStatic = false,
  }) {
    instabilitySpeed = instabilityMagnitude * (_random.nextBool() ? 1 : -1);
  }

  double get currentAngle {
    if (isStatic || age < instabilityDelay) return baseAngle;
    final t = age - instabilityDelay;
    return baseAngle + instabilitySpeed * t;
  }

  Offset get start {
    final angle = currentAngle;
    return center - Offset(cos(angle), sin(angle)) * (length / 2);
  }

  Offset get end {
    final angle = currentAngle;
    return center + Offset(cos(angle), sin(angle)) * (length / 2);
  }

  /// 0 = stable, 1 = totalement instable (utile pour la couleur/feedback visuel).
  double get instabilityRatio {
    if (isStatic) return 0;
    final t = (age - instabilityDelay) / 4; // ~4s pour aller à fond
    return t.clamp(0.0, 1.0);
  }

  void update(double dt) {
    if (isStatic) return; // un obstacle fixe ne vieillit pas
    age += dt;
  }
}
