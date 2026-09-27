import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/ball.dart';
import '../models/ruler.dart';
import '../utils/physics_utils.dart';

/// À utiliser comme body d'un Scaffold (ou dans un SizedBox.expand),
/// pas de taille infinie : il a besoin de contraintes finies pour dessiner.
class BallRulerGame extends StatefulWidget {
  const BallRulerGame({super.key});

  @override
  State<BallRulerGame> createState() => BallRulerGameState();
}

class BallRulerGameState extends State<BallRulerGame>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  static const Offset _startPosition = Offset(180, 80);
  static const int _physicsSubsteps = 4; // évite de "traverser" une règle en cas de chute rapide

  final Ball _ball = Ball(position: _startPosition);
  final List<Ruler> _rulers = [
    // règle de départ : sans elle, la bille tombe dès le lancement du jeu
    Ruler(center: const Offset(180, 160)),
  ];

  double _elapsed = 0;
  bool _gameOver = false;
  Size _gameSize = Size.zero;

  // Défilement de la caméra : maintient la bille près du haut de l'écran.
  double _scrollY = 0;
  static const double _cameraTargetFraction = 0.28; // position cible de la bille à l'écran
  static const double _cameraCatchUpSpeed = 3.0; // vitesse de rattrapage

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    // ignore les gros sauts de dt (reprise d'app en arrière-plan, etc.)
    if (_gameOver || dt <= 0 || dt > 0.05) return;

    setState(() {
      _elapsed += dt;
      for (final r in _rulers) {
        r.update(dt);
      }
      _stepPhysics(dt);
      _updateCamera(dt);
      _checkGameOver();
    });
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
    for (final r in _rulers) {
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

  void _checkGameOver() {
    final screenY = _ball.position.dy - _scrollY;
    if (_gameSize.height > 0 && screenY > _gameSize.height + 40) {
      _gameOver = true;
      _ticker.stop();
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (_gameOver) return;
    // la règle existe déjà (forme et longueur fixes) : le joueur choisit
    // juste où la poser pour qu'elle intercepte la bille. Le tap est en
    // coordonnées écran, on le convertit en coordonnées monde via le scroll.
    final worldPosition = details.localPosition + Offset(0, _scrollY);
    setState(() => _rulers.add(Ruler(center: worldPosition)));
  }

  void restart() {
    setState(() {
      _ball.position = _startPosition;
      _ball.velocity = Offset.zero;
      _rulers
        ..clear()
        ..add(Ruler(center: const Offset(180, 160)));
      _elapsed = 0;
      _gameOver = false;
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
                painter: _GamePainter(ball: _ball, rulers: _rulers, scrollY: _scrollY),
                size: _gameSize,
              ),
              Positioned(
                top: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    _elapsed.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 28, color: Colors.white),
                  ),
                ),
              ),
              if (_gameOver)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Game Over',
                        style: TextStyle(fontSize: 40, color: Colors.red),
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

class _GamePainter extends CustomPainter {
  final Ball ball;
  final List<Ruler> rulers;
  final double scrollY;

  _GamePainter({required this.ball, required this.rulers, required this.scrollY});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    final cameraOffset = Offset(0, scrollY);

    for (final r in rulers) {
      final paint = Paint()
        ..color = Color.lerp(Colors.greenAccent, Colors.redAccent, r.instabilityRatio)!
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
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
