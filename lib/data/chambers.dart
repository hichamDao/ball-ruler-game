import 'dart:math';
import 'dart:ui';

import '../models/chamber.dart';

/// Quelques chambres écrites à la main pour valider la sensation de jeu.
/// Au-delà de cette liste, [generateChamber] prend le relais pour une
/// difficulté procédurale qui augmente doucement (mode hybride).
final List<Chamber> handCraftedChambers = [
  const Chamber(
    height: 420,
    targetCenterX: 180,
    targetWidth: 90,
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
    targetWidth: 70,
    obstacles: [
      ObstacleSpec(relativeCenter: Offset(140, 180), length: 90, angle: 0.3),
      ObstacleSpec(relativeCenter: Offset(260, 340), length: 90, angle: -0.3),
    ],
  ),
];

final Random _levelRandom = Random();

/// Génère une chambre au-delà des niveaux écrits à la main : la zone cible
/// rétrécit et le nombre d'obstacles augmente doucement avec [index].
/// [screenWidth] permet de garder la zone cible et les obstacles à
/// l'intérieur de l'écran du joueur.
Chamber generateChamber(int index, double screenWidth) {
  final int difficulty = (index - handCraftedChambers.length).clamp(0, 30);
  final double targetWidth = (90.0 - difficulty * 1.5).clamp(45.0, 90.0);
  final int obstacleCount = 1 + (difficulty ~/ 4).clamp(0, 3);
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
