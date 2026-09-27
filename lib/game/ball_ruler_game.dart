import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/chambers.dart';
import '../models/ball.dart';
import '../models/chamber.dart';
import '../models/ruler.dart';
import '../utils/physics_utils.dart';

/// À utiliser comme body d'un Scaffold (ou dans un SizedBox.expand),
/// pas de taille infinie : il a besoin de contraintes finies pour dessiner.
class BallRulerGame extends StatefulWidget {
  const BallRulerGame({super.key});

  @override
  State<BallRulerGame> createState() => BallRulerGameState();
}

/// Les deux temps du jeu de stratégie/arcade :
/// - [planning] : le temps est figé, le joueur pose ses règles avec un
///   budget limité, puis lance la chute quand il est prêt.
/// - [falling] : la physique reprend, le joueur ne peut plus poser que sa
///   réserve d'urgence (plus petite) pour corriger une erreur.
enum GamePhase { planning, falling, gameOver }

class BallRulerGameState extends State<BallRulerGame>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  static const Offset _startPosition = Offset(180, 80);
  static const int _physicsSubsteps = 4; // évite de "traverser" une règle en cas de chute rapide

  // Budgets par défaut (à ajuster facilement une fois la sensation testée) :
  // pas de minuteur en planification, progression hybride (chambres écrites
  // à la main puis procédurales), réserve d'urgence rechargée à chaque
  // chambre. Voir data/chambers.dart pour la progression de difficulté.
  static const int _planningBudgetPerChamber = 3;
  static const int _emergencyBudgetPerChamber = 1;

  final Ball _ball = Ball(position: _startPosition);
  final List<Ruler> _activeRulers = [];

  GamePhase _phase = GamePhase.planning;
  int _chamberIndex = 0;
  double _chamberStartY = 0; // sommet de la chambre courante, coordonnées monde
  late Chamber _chamber;
  int _planningBudget = _planningBudgetPerChamber;
  int _emergencyBudget = _emergencyBudgetPerChamber;

  double _elapsed = 0; // ne compte que le temps en chute (voir _onTick)
  Size _gameSize = Size.zero;

  // Défilement de la caméra : maintient la bille près du haut de l'écran.
  double _scrollY = 0;
  static const double _cameraTargetFraction = 0.28; // position cible de la bille à l'écran
  static const double _cameraCatchUpSpeed = 3.0; // vitesse de rattrapage

  @override
  void initState() {
    super.initState();
    _loadChamber(0);
    _ticker = createTicker(_onTick)..start();
  }

  void _loadChamber(int index) {
    _chamber = index < handCraftedChambers.length
        ? handCraftedChambers[index]
        : generateChamber(index, _gameSize.width > 0 ? _gameSize.width : 360.0);
    _activeRulers.addAll(_chamber.buildObstacles(_chamberStartY));
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    // ignore les gros sauts de dt (reprise d'app en arrière-plan, etc.)
    if (_phase == GamePhase.gameOver || dt <= 0 || dt > 0.05) return;

    setState(() {
      if (_phase == GamePhase.falling) {
        _elapsed += dt;
        for (final r in _activeRulers) {
          r.update(dt); // no-op pour les obstacles statiques
        }
        _stepPhysics(dt);
        _updateCamera(dt);
        _checkCameraGameOver();
        _checkChamberBoundary();
      }
      _cullOffscreenRulers();
    });
  }

  void _cullOffscreenRulers() {
    // libère la mémoire et évite de tester des collisions inutiles contre
    // des règles largement scrollées hors champ.
    _activeRulers.removeWhere((r) => r.center.dy - _scrollY < -200);
  }

  void _updateCamera(double dt) {
    if (_gameSize.height <= 0) return;
    final targetScreenY = _gameSize.height * _cameraTargetFraction;
    final desiredScrollY = _ball.position.dy - targetScreenY;
    // ne défile que vers le bas (la caméra ne remonte jamais) et avec un
    // léger temps de rattrapage : si la bille tombe trop vite sans être
    // rattrapée par une règle, elle peut quand même sortir de l'écran.
    if (desiredScrollY > _scrollY) {
      _scrollY += (desiredScrollY - _scrollY) * min(1.0, _cameraCatchUpSpeed * dt);
    }
  }

  void _stepPhysics(double dt) {
    final subDt = dt / _physicsSubsteps;
    for (var i = 0; i < _physicsSubsteps; i++) {
      _ball.applyGravity(subDt);
      _ball.updatePosition(subDt);
      _resolveCollisions();
      _resolveWalls();
    }
  }

  void _resolveWalls() {
    if (_gameSize.width <= 0) return;
    final r = _ball.radius;
    final pos = _ball.position;
    final vel = _ball.velocity;

    if (pos.dx - r < 0) {
      _ball.position = Offset(r, pos.dy);
      if (vel.dx < 0) _ball.velocity = Offset(-vel.dx, vel.dy);
    } else if (pos.dx + r > _gameSize.width) {
      _ball.position = Offset(_gameSize.width - r, pos.dy);
      if (vel.dx > 0) _ball.velocity = Offset(-vel.dx, vel.dy);
    }
  }

  void _resolveCollisions() {
    for (final r in _activeRulers) {
      final result = ballRulerCollision(
        _ball.position,
        _ball.radius,
        r.start,
        r.end,
      );
      if (!result.hit) continue;

      // repositionne la bille exactement au contact, du bon côté de la règle
      _ball.position = result.closestPoint + result.normal * _ball.radius;

      // on retire uniquement la composante de vitesse qui va VERS la règle ;
      // la composante tangentielle est conservée, c'est elle qui fait rouler
      // la bille le long de la pente (et rouler hors de la règle une fois
      // celle-ci devenue instable/inclinée).
      final vn = _ball.velocity.dx * result.normal.dx +
          _ball.velocity.dy * result.normal.dy;
      if (vn < 0) {
        _ball.velocity -= result.normal * vn;
      }
    }
  }

  /// Garde-fou existant : si la bille tombe plus vite que la caméra ne peut
  /// rattraper, elle finit par sortir de l'écran visible.
  void _checkCameraGameOver() {
    final screenY = _ball.position.dy - _scrollY;
    if (_gameSize.height > 0 && screenY > _gameSize.height + 40) {
      _triggerGameOver();
    }
  }

  /// Vérifie si la bille a atteint le bas de la chambre courante : elle passe
  /// à la chambre suivante si elle est dans la zone cible, sinon la partie
  /// s'arrête (elle est "sortie" de la chambre sans avoir trouvé la sortie).
  void _checkChamberBoundary() {
    final bottomY = _chamberStartY + _chamber.height;
    if (_ball.position.dy - _ball.radius < bottomY) return;

    final withinTarget =
        (_ball.position.dx - _chamber.targetCenterX).abs() <= _chamber.targetWidth / 2;
    if (withinTarget) {
      _advanceToNextChamber();
    } else {
      _triggerGameOver();
    }
  }

  void _advanceToNextChamber() {
    _chamberIndex++;
    _chamberStartY += _chamber.height;
    _loadChamber(_chamberIndex);
    _planningBudget = _planningBudgetPerChamber;
    _emergencyBudget = _emergencyBudgetPerChamber;
    _phase = GamePhase.planning;
  }

  void _triggerGameOver() {
    _phase = GamePhase.gameOver;
    _ticker.stop();
  }

  void _onTapDown(TapDownDetails details) {
    if (_phase == GamePhase.gameOver) return;
    final worldPosition = details.localPosition + Offset(0, _scrollY);

    if (_phase == GamePhase.planning) {
      if (_planningBudget <= 0) return;
      setState(() {
        _activeRulers.add(Ruler(center: worldPosition));
        _planningBudget--;
      });
    } else if (_phase == GamePhase.falling) {
      if (_emergencyBudget <= 0) return;
      setState(() {
        _activeRulers.add(Ruler(center: worldPosition));
        _emergencyBudget--;
      });
    }
  }

  /// Lance la chute une fois que le joueur a fini de placer ses règles.
  void _startFalling() {
    if (_phase != GamePhase.planning) return;
    setState(() => _phase = GamePhase.falling);
  }

  void restart() {
    setState(() {
      _ball.position = _startPosition;
      _ball.velocity = Offset.zero;
      _activeRulers.clear();
      _chamberIndex = 0;
      _chamberStartY = 0;
      _loadChamber(0);
      _planningBudget = _planningBudgetPerChamber;
      _emergencyBudget = _emergencyBudgetPerChamber;
      _elapsed = 0;
      _phase = GamePhase.planning;
      _lastTick = Duration.zero;
      _scrollY = 0;
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _gameSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapDown: _onTapDown,
          child: Stack(
            children: [
              CustomPaint(
                painter: _GamePainter(
                  ball: _ball,
                  rulers: _activeRulers,
                  scrollY: _scrollY,
                  chamber: _chamber,
                  chamberStartY: _chamberStartY,
                ),
                size: _gameSize,
              ),
              Positioned(
                top: 24,
                left: 16,
                child: _HudText('Chambre ${_chamberIndex + 1}'),
              ),
              Positioned(
                top: 24,
                right: 16,
                child: _HudText(_elapsed.toStringAsFixed(2)),
              ),
              if (_phase == GamePhase.planning)
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HudText('Règles disponibles : $_planningBudget'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _startFalling,
                        child: const Text('Lancer'),
                      ),
                    ],
                  ),
                ),
              if (_phase == GamePhase.falling)
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _HudText('Urgence : $_emergencyBudget'),
                  ),
                ),
              if (_phase == GamePhase.gameOver)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Game Over',
                        style: TextStyle(fontSize: 40, color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chambre atteinte : ${_chamberIndex + 1}',
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: restart,
                        child: const Text('Rejouer'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HudText extends StatelessWidget {
  final String text;
  const _HudText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 18, color: Colors.white));
  }
}

class _GamePainter extends CustomPainter {
  final Ball ball;
  final List<Ruler> rulers;
  final double scrollY;
  final Chamber chamber;
  final double chamberStartY;

  _GamePainter({
    required this.ball,
    required this.rulers,
    required this.scrollY,
    required this.chamber,
    required this.chamberStartY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    final cameraOffset = Offset(0, scrollY);

    // Zone cible en bas de la chambre courante : repère visuel uniquement,
    // ne bloque pas la bille (c'est la "sortie" vers la chambre suivante).
    final targetY = chamberStartY + chamber.height - scrollY;
    final targetLeft = chamber.targetCenterX - chamber.targetWidth / 2;
    final targetRight = chamber.targetCenterX + chamber.targetWidth / 2;
    canvas.drawLine(
      Offset(targetLeft, targetY),
      Offset(targetRight, targetY),
      Paint()
        ..color = Colors.amberAccent
        ..strokeWidth = 4,
    );

    for (final r in rulers) {
      final paint = Paint()
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      paint.color = r.isStatic
          ? Colors.blueGrey.shade200
          : Color.lerp(Colors.greenAccent, Colors.redAccent, r.instabilityRatio)!;
      canvas.drawLine(r.start - cameraOffset, r.end - cameraOffset, paint);
    }

    canvas.drawCircle(
      ball.position - cameraOffset,
      ball.radius,
      Paint()..color = Colors.blueGrey.shade300,
    );
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}
