import 'dart:math';
import 'dart:ui';

import '../models/chamber.dart';

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
      // un premier obstacle fixe, servant de repère pour poser sa première
      // règle par rapport à lui. Légèrement incliné (voir note plus bas).
      ObstacleSpec(relativeCenter: Offset(190, 190), length: 90, angle: 0.15),
    ],
  ),
  const Chamber(
    height: 460,
    targetCenterX: 260,
    targetWidth: 80,
    obstacles: [
      // légèrement décalé et incliné : un obstacle fixe ne se stabilise
      // jamais tout seul (contrairement aux règles du joueur), donc on
      // évite de le placer parfaitement à plat pile sous le point de
      // départ, sous peine de voir la bille s'y équilibrer indéfiniment.
      ObstacleSpec(relativeCenter: Offset(220, 220), length: 100, angle: 0.2),
    ],
  ),
  const Chamber(
    height: 500,
    targetCenterX: 100,
    targetWidth: 60,
    obstacles: [
      ObstacleSpec(relativeCenter: Offset(140, 180), length: 90, angle: 0.3),
      ObstacleSpec(relativeCenter: Offset(260, 340), length: 90, angle: -0.3),
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
    return ObstacleSpec(relativeCenter: Offset(relX, relY), angle: angle);
  });

  return Chamber(
    height: 420.0 + obstacleCount * 90.0,
    targetCenterX: 40.0 + _levelRandom.nextDouble() * (safeWidth - 80.0),
    targetWidth: targetWidth,
    obstacles: obstacles,
  );
}
