import 'dart:math';
import 'dart:ui';

import '../models/chamber.dart';
import '../models/furniture_type.dart';

/// Quelques chambres écrites à la main pour valider la sensation de jeu.
/// Au-delà de cette liste, [generateChamber] prend le relais pour une
/// difficulté procédurale qui augmente doucement (mode hybride).
final List<Chamber> handCraftedChambers = [
  const Chamber(
    height: 420,
    // décalée par rapport au point de départ de la bille (x=180) : tomber
    // tout droit sans poser de règle rate la zone, même en chambre 1.
    targetCenterX: 260,
    targetWidth: 100,
    obstacles: [
      // une chaise comme premier repère, servant de point d'appui pour
      // poser sa première règle par rapport à elle.
      ObstacleSpec(
        relativeCenter: Offset(190, 190),
        length: 90,
        angle: 0.15,
        furniture: FurnitureType.chair,
      ),
    ],
  ),
  const Chamber(
    height: 460,
    targetCenterX: 260,
    targetWidth: 80,
    obstacles: [
      // un lit : la bille y rebondit (voir Ruler.restitution), premier
      // meuble à comportement particulier que le joueur rencontre.
      // Légèrement incliné (un obstacle fixe ne se stabilise jamais tout
      // seul, donc on évite le plat parfait pile sous le point de départ).
      ObstacleSpec(
        relativeCenter: Offset(220, 220),
        length: 100,
        angle: 0.2,
        furniture: FurnitureType.bed,
      ),
    ],
  ),
  const Chamber(
    height: 500,
    targetCenterX: 100,
    targetWidth: 60,
    obstacles: [
      ObstacleSpec(
        relativeCenter: Offset(140, 180),
        length: 90,
        angle: 0.3,
        furniture: FurnitureType.table,
      ),
      // une armoire posée presque à la verticale : elle agit comme un mur
      // qu'il faut contourner par la gauche pour atteindre la sortie.
      ObstacleSpec(
        relativeCenter: Offset(220, 350),
        length: 140,
        angle: 1.5708,
        furniture: FurnitureType.wardrobe,
      ),
    ],
  ),
];

final Random _levelRandom = Random();

/// Génère une chambre au-delà des niveaux écrits à la main : la zone cible
/// continue de rétrécir et le nombre d'obstacles augmente doucement avec
/// [index], en repartant des valeurs de la dernière chambre écrite à la main
/// (60 de large, 2 obstacles) pour que la difficulté ne redescende jamais.
/// [screenWidth] permet de garder la zone cible et les obstacles à
/// l'intérieur de l'écran du joueur.
Chamber generateChamber(int index, double screenWidth) {
  final int beyond = (index - handCraftedChambers.length).clamp(0, 30);
  final double targetWidth = (60.0 - beyond * 5.0).clamp(40.0, 60.0);
  final int obstacleCount = 2 + (beyond ~/ 5).clamp(0, 3);
  final double safeWidth = screenWidth > 120 ? screenWidth : 360.0;

  final obstacles = List.generate(obstacleCount, (i) {
    final relY = 120.0 + i * 140.0;
    final relX = 60.0 + _levelRandom.nextDouble() * (safeWidth - 120.0);
    final angle = (_levelRandom.nextDouble() - 0.5) * 0.6;
    final furniture = _levelRandom.nextBool() ? FurnitureType.chair : FurnitureType.table;
    return ObstacleSpec(relativeCenter: Offset(relX, relY), angle: angle, furniture: furniture);
  });

  return Chamber(
    height: 420.0 + obstacleCount * 90.0,
    targetCenterX: 40.0 + _levelRandom.nextDouble() * (safeWidth - 80.0),
    targetWidth: targetWidth,
    obstacles: obstacles,
  );
}
