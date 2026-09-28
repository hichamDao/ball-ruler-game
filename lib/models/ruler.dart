import 'dart:math';
import 'dart:ui';

import 'furniture_type.dart';

/// Une règle-plateforme à la forme fixe (longueur fixe, horizontale au départ).
/// Le joueur ne la dessine plus : il choisit juste où elle est posée.
/// Une fois posée, elle devient de plus en plus instable : son angle dérive
/// dans le temps jusqu'à ce que la bille n'ait plus assez d'adhérence.
///
/// Le sens de bascule (gauche/droite) N'EST PAS tiré au hasard : c'est le
/// côté où la bille pose son poids sur la règle qui décide (comme une vraie
/// balançoire). Ainsi, en planification, le joueur peut prédire de façon
/// fiable de quel côté une règle va finir par pencher.
class Ruler {
  Offset center;
  final double baseAngle;
  final double length;
  double age = 0; // secondes écoulées depuis la pose

  final double instabilityDelay;
  final double instabilityMagnitude;

  /// Côté utilisé si la règle n'est JAMAIS touchée par la bille avant de
  /// devenir instable (cas limite d'une règle "décor" jamais utilisée) :
  /// -1 = penche vers "start" (gauche), 1 = penche vers "end" (droite).
  /// Décidé une fois pour toutes à la pose, selon la position de la règle
  /// à l'écran (voir _onTapDown dans ball_ruler_game.dart).
  final double fallbackTipSign;

  /// Côté vers lequel la bille pèse actuellement (ou a pesé en dernier) sur
  /// la règle : -1 vers "start", 1 vers "end", null tant qu'aucun contact
  /// n'a encore eu lieu. Mis à jour à chaque collision (voir registerContact).
  double? _contactSign;

  /// Obstacle fixe d'une chambre : ne devient jamais instable, rendu dans un
  /// style différent des règles posées par le joueur.
  final bool isStatic;

  /// Type de meuble pour le rendu (et, pour le lit, le rebond). N'a d'effet
  /// que sur les obstacles fixes ([isStatic] = true) : une règle posée par
  /// le joueur garde son rendu habituel quel que soit ce champ.
  final FurnitureType furniture;

  Ruler({
    required this.center,
    this.baseAngle = 0, // horizontale par défaut
    this.length = 110,
    this.instabilityDelay = 2.5,
    this.instabilityMagnitude = 0.6,
    this.fallbackTipSign = 1,
    this.isStatic = false,
    this.furniture = FurnitureType.plank,
  });

  /// À appeler à chaque collision entre la bille et cette règle : détermine
  /// de quel côté du centre la bille pose son poids, ce qui décidera du sens
  /// de bascule une fois le délai d'instabilité écoulé.
  void registerContact(Offset contactPoint) {
    if (isStatic) return;
    final angle = currentAngle;
    final axis = Offset(cos(angle), sin(angle)); // direction "vers end"
    final relative = contactPoint - center;
    final projection = relative.dx * axis.dx + relative.dy * axis.dy;
    _contactSign = projection >= 0 ? 1.0 : -1.0;
  }

  double get currentAngle {
    if (isStatic || age < instabilityDelay) return baseAngle;
    final t = age - instabilityDelay;
    final sign = _contactSign ?? fallbackTipSign;
    return baseAngle + instabilityMagnitude * sign * t;
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

  /// Coefficient de rebond : 0 = la bille ne rebondit pas (comportement
  /// standard de toutes les règles/meubles), > 0 = elle repart dans le sens
  /// opposé à la collision. Seul le lit rebondit ; tout le reste garde le
  /// comportement d'origine.
  double get restitution => furniture == FurnitureType.bed ? 0.65 : 0.0;

  void update(double dt) {
    if (isStatic) return; // un obstacle fixe ne vieillit pas
    age += dt;
  }
}
