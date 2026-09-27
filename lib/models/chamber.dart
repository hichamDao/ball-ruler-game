import 'dart:ui';

import 'ruler.dart';

/// Un obstacle fixe défini en coordonnées LOCALES à sa chambre : l'origine Y
/// est le sommet de la chambre. Il est traduit en coordonnées monde au
/// moment où la chambre est chargée (voir [Chamber.buildObstacles]).
class ObstacleSpec {
  final Offset relativeCenter;
  final double length;
  final double angle;

  const ObstacleSpec({
    required this.relativeCenter,
    this.length = 110,
    this.angle = 0,
  });
}

/// Un segment vertical du niveau : sa hauteur, ses obstacles fixes, et la
/// zone cible que la bille doit atteindre en bas pour passer à la chambre
/// suivante. Si elle rate la zone cible, la partie se termine.
class Chamber {
  final double height;
  final List<ObstacleSpec> obstacles;
  final double targetCenterX;
  final double targetWidth;

  const Chamber({
    required this.height,
    this.obstacles = const [],
    required this.targetCenterX,
    this.targetWidth = 70,
  });

  /// Matérialise les obstacles de la chambre en [Ruler] statiques, positionnés
  /// en coordonnées monde à partir du sommet [chamberStartY] de la chambre.
  List<Ruler> buildObstacles(double chamberStartY) {
    return obstacles
        .map((spec) => Ruler(
              center: spec.relativeCenter + Offset(0, chamberStartY),
              baseAngle: spec.angle,
              length: spec.length,
              isStatic: true,
            ))
        .toList();
  }
}
